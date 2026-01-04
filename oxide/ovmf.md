# OVMF firmware and ACPI tables: What VMMs must implement

Modern OVMF firmware (edk2-stable202108 and later) **no longer includes hardcoded ACPI tables** and instead requires the Virtual Machine Monitor (VMM) to provide them via QEMU’s fw_cfg interface. This architectural change, merged in August 2021, means VMMs like Oxide’s Propolis must implement the fw_cfg table-loader protocol to support current OVMF versions— a significant undertaking that involves emulating hardware interfaces, generating dynamic ACPI tables, and implementing a linker/loader script interpreter. Alternative approaches exist, including Cloud Hypervisor’s direct RSDP placement and custom OVMF builds, but each involves trade-offs between implementation complexity and compatibility.

-----

## OVMF and EDK2: UEFI firmware for virtual machines

**OVMF (Open Virtual Machine Firmware)** is the `OvmfPkg` package within Intel’s EDK II (EFI Development Kit II), providing UEFI firmware support for QEMU/KVM virtual machines.  The relationship between the key components is hierarchical: **TianoCore** is the open-source community supporting UEFI implementation; **EDK II** is the development framework and build system;  and **OVMF** is a specific firmware package targeting virtual machines.

OVMF implements the standard UEFI Platform Initialization boot phases: **SEC** (Security) executes from the reset vector at `0xFFFF_FFF0`, transitioning from 16-bit real mode through 32-bit protected mode to 64-bit long mode; **PEI** (Pre-EFI Initialization) decompresses the main firmware volumes and initializes memory; **DXE** (Driver Execution Environment) loads device drivers including VirtIO block and network drivers; and **BDS** (Boot Device Selection) enumerates boot devices and hands off to the OS loader.

The firmware image is typically **2MB** in size, with a 208KB uncompressed SEC region, a 1712KB LZMA-compressed region containing PEI and DXE modules, and 128KB of non-volatile variable storage. QEMU maps this image just below **4GB** in guest-physical address space using the pflash device, which provides CFI (Common Flash Interface) emulation for variable persistence.

UEFI replaced legacy BIOS in modern virtualization for several compelling reasons: support for disks larger than **2TB** via GPT partitioning, **Secure Boot** for cryptographic verification of boot components, native 64-bit operation, and industry momentum as Intel, AMD, and Microsoft deprecate legacy BIOS support. CSM (Compatibility Support Module) for legacy OS support is deliberately excluded from most OVMF builds for security and simplicity. 

-----

## ACPI tables provide hardware topology to guest operating systems

ACPI (Advanced Configuration and Power Interface) tables are firmware-provided data structures that describe system hardware topology, power management capabilities, and interrupt routing to the operating system. Without accurate ACPI tables, a guest OS cannot enumerate CPUs, configure interrupts, manage power states, or discover platform devices.

### The ACPI table hierarchy

The discovery mechanism begins with the **RSDP** (Root System Description Pointer), located either by scanning memory addresses `0xE0000-0xFFFFF` on legacy BIOS systems or through the EFI Configuration Table on UEFI systems.  The RSDP points to the **XSDT** (Extended System Description Table), which contains 64-bit pointers to all other system description tables. 

Critical tables include:

**MADT (Multiple APIC Description Table)** describes interrupt controllers and CPU topology.  Each CPU has a Local APIC entry (Type 0) mapping ACPI Processor ID to APIC ID, with flags indicating whether the processor is enabled. The I/O APIC entry (Type 1) specifies the MMIO base address (typically `0xFEC00000`) and Global System Interrupt base.  Interrupt Source Override entries (Type 2) remap legacy ISA IRQs—for instance, the PIT timer at ISA IRQ 0 typically maps to GSI 2 when APIC mode is enabled.

**FADT (Fixed ACPI Description Table)** contains pointers to the DSDT and FACS, plus critical hardware register addresses: the PM1a Event Block, PM1a Control Block, PM Timer Block (the **3.579545 MHz** ACPI timer), and GPE (General Purpose Events) blocks. The SCI (System Control Interrupt) number and SMI command port are also specified here.

**DSDT (Differentiated System Description Table)** contains AML (ACPI Machine Language) bytecode describing all platform devices. This includes `_PRT` methods for PCI interrupt routing, `_CRS` methods for current resource settings, and power management methods (`_S3` for suspend, `_S5` for shutdown). SSDT (Secondary System Description Tables) supplement the DSDT with additional device definitions, commonly used for CPU hotplug, memory hotplug, and features like TPM and VM Generation ID.

**MCFG** provides the PCIe Enhanced Configuration Access Mechanism (ECAM) base address, allowing memory-mapped access to the full **4KB** per-function configuration space (versus 256 bytes with legacy PCI I/O ports). 

**SRAT and SLIT** describe NUMA topology: SRAT maps processors and memory ranges to proximity domains (NUMA nodes), while SLIT provides a matrix of relative memory access latencies between nodes  (where **10** represents local access).

### Why accuracy is critical

Incorrect ACPI tables cause cascading failures: wrong MADT entries prevent multi-processor initialization; incorrect interrupt routing causes device driver failures; missing MCFG prevents PCIe device access; and incorrect power management information can cause system hangs during shutdown or sleep transitions. The guest OS fundamentally trusts ACPI tables to accurately describe the virtual hardware topology.

-----

## The historical shift: OVMF stopped including hardcoded tables

Prior to 2021, OVMF contained a fallback mechanism: the `AcpiPlatformDxe` driver would first check for QEMU’s `etc/table-loader` fw_cfg file and use QEMU-provided tables if available, falling back to statically compiled tables in `OvmfPkg/AcpiTables/` otherwise.  The static tables included DSDT (`Dsdt.asl`), FADT (`Facp.aslc`), MADT (`Madt.aslc`), and HPET (`Hpet.aslc`), with runtime patching to adjust CPU counts and power states.

This changed with a **43-patch series** by Laszlo Ersek (Red Hat), posted on May 26, 2021, titled “OvmfPkg: remove Xen support.” Patch 03/43 was the critical change: switching from `OvmfPkg/AcpiPlatformDxe/AcpiPlatformDxe.inf` to `OvmfPkg/AcpiPlatformDxe/QemuFwCfgAcpiPlatformDxe.inf`, which only supports the fw_cfg code path.  

The changes were released in **edk2-stable202108** (August 27, 2021).  The commit message noted this “only removes effectively dead code; the QEMU ACPI linker-loader has taken priority since QEMU 1.7.1 (2014).” 

The rationale was compelling:

- **Dynamic hardware configuration**: QEMU owns the virtual hardware configuration, which can change via command-line arguments. Static firmware tables cannot reflect this. 
- **Hotplug support**: CPU, memory, and PCI hotplug require dynamic ACPI table updates that embedded tables cannot provide.
- **Firmware simplicity**: The table-loader interface requires “the firmware to know the least possible about ACPI table specifics.” 
- **Xen separation**: Xen-specific ACPI handling moved to a dedicated `OvmfXen.dsc` platform. 

For VMM developers: targeting OVMF after August 2021 requires implementing the QEMU fw_cfg ACPI linker/loader interface, unless using a specialized platform variant like `OvmfBhyve.dsc`. 

-----

## The fw_cfg interface: how QEMU passes data to firmware

The **fw_cfg** (firmware configuration) device is QEMU’s mechanism for passing configuration data to guest firmware.  On x86, it uses I/O ports: the **selector register** at port `0x510` (16-bit, write-only) chooses which data item to access; the **data register** at port `0x511` (8-bit) provides sequential byte access;  and the optional **DMA interface** at port `0x514` enables bulk transfers. 

### File-based namespace

Writing selector value `0x0019` (`FW_CFG_FILE_DIR`) and reading from the data port returns a directory of available files. Each 64-byte entry contains the file size, selector key, and a 56-character null-terminated filename.  Standard ACPI-related files include:

|File path         |Contents                       |
|------------------|-------------------------------|
|`etc/table-loader`|Linker/loader commands         |
|`etc/acpi/tables` |Concatenated ACPI table blob   |
|`etc/acpi/rsdp`   |Root System Description Pointer|

### The table-loader protocol

The table-loader is a command script allowing QEMU to instruct firmware to allocate memory, patch pointers, and calculate checksums—without either side needing complete knowledge of the other’s memory layout. Each command is a **128-byte** structure:

**ALLOCATE** (command 0x01) instructs firmware to download a blob from fw_cfg and place it in guest memory.  The command specifies alignment requirements (power of 2) and a zone hint: `ZONE_HIGH` for memory above 1MB or `ZONE_FSEG` for the `0xF0000-0xFFFFF` region where firmware traditionally places ACPI tables. 

**ADD_POINTER** (command 0x02) patches a pointer value between allocated blobs.   The firmware reads the current value at `dest_blob[offset]`, adds the guest address of `src_blob`, and writes the result back. Pointer sizes of 1, 2, 4, or 8 bytes are supported. This links XSDT entries to individual tables, FADT to DSDT, and other cross-table references.

**ADD_CHECKSUM** (command 0x03) calculates an ACPI-style checksum over a byte range and stores it at a specified offset.   The checksum algorithm ensures the sum of all bytes in the range (including the checksum byte) equals zero.

**WRITE_POINTER** (command 0x04) enables bidirectional communication by writing a pointer value back to QEMU via fw_cfg DMA.  This is used for features like VMGENID and hardware error reporting (GHES) where QEMU needs to know firmware-allocated addresses. 

### DMA interface

For bulk transfers, the DMA interface accepts a 16-byte control structure at a guest-physical address written to port `0x514`. The structure contains control bits (read/write/skip/select), transfer length, and target address. Writing the address triggers the operation; the control field’s bit 0 indicates errors upon completion.  DMA availability is detected by reading port `0x514`, which returns the ASCII string “QEMU CFG” if supported. 

-----

## QEMU generates ACPI tables dynamically from VM configuration

QEMU’s ACPI generation subsystem constructs tables programmatically at VM startup, reflecting the actual hardware configuration.  The key source files are:

- `hw/i386/acpi-build.c`: x86 PC-specific table generation
- `hw/acpi/aml-build.c`: Core AML bytecode building API
- `hw/acpi/bios-linker-loader.c`: Table-loader command generation
- `include/hw/acpi/aml-build.h`: AML builder type definitions

### The AML building API

The API provides a C-based domain-specific language for constructing AML bytecode. Functions like `aml_device()`, `aml_method()`, `aml_name_decl()`, and `aml_resource_template()` create AML structures that are appended to parent objects via `aml_append()`. For example:

```c
Aml *dev = aml_device("HPET");
aml_append(dev, aml_name_decl("_HID", aml_eisaid("PNP0103")));
aml_append(dev, aml_name_decl("_UID", aml_int(0)));
```

This generates the AML bytecode for a device object with `_HID` (Hardware ID) and `_UID` (Unique ID) declarations.

### Configuration drivers

**vCPU topology** drives MADT generation. The `build_madt()` function iterates over `possible_cpus`, creating Local APIC entries (Type 0) for CPUs with APIC IDs below 255, or x2APIC entries (Type 9) for larger topologies. Each entry includes the ACPI Processor ID, APIC ID, and enabled flag.

**Memory and NUMA** configuration generates SRAT (memory affinity structures mapping address ranges to proximity domains) and SLIT (distance matrices). The `build_srat_memory()` function creates 40-byte Memory Affinity structures with base address, length, proximity domain, and flags indicating hotplug capability.

**PCI devices** generate `_PRT` (PCI Routing Table) methods in the DSDT, mapping device/function interrupt pins to interrupt sources. The `build_mcfg()` function creates the MCFG table pointing to the PCIe ECAM region (typically `0xB0000000` for Q35).

### Hotplug support

CPU hotplug uses a register interface at I/O port `0x0cd8` (ICH9) or `0xaf00` (PIIX).  The generated AML includes a `\_SB.CPUS` container device with `CSCN` (CPU Scan) and `CSTA` (CPU Status) methods. Individual CPU device objects include `_STA` (Status), `_EJ0` (Eject), and `_MAT` (MADT) methods.

Memory hotplug operates similarly via registers at base `0x0a00`, with generated AML creating `\_SB.MHPD` device and per-slot device objects (`MSLOT0`, etc.) with status, resource, and scan methods.

### Table linking

The `BIOSLinker` structure accumulates commands that will form the `etc/table-loader` file. After building individual tables, QEMU calls `bios_linker_loader_add_pointer()` to create cross-table links and `bios_linker_loader_add_checksum()` to set up checksum calculations.  The final command list is registered with fw_cfg alongside the table data.

-----

## What Propolis must implement to support modern OVMF

Propolis, Oxide Computer’s Rust-based VMM built on illumos bhyve, faces a specific challenge:  modern OVMF expects ACPI tables via fw_cfg, but bhyve traditionally places tables directly in guest memory at fixed addresses starting at `0xf2400`. 

### fw_cfg device emulation

Propolis must implement:

- **I/O port handlers** for `0x510` (selector), `0x511` (data), and `0x514` (DMA address)
- **File directory management** responding to `FW_CFG_FILE_DIR` (selector `0x0019`)
- **Signature verification** returning “QEMU” for `FW_CFG_SIGNATURE` (selector `0x0000`)  
- **Feature bitmap** at `FW_CFG_ID` (selector `0x0001`) indicating DMA support

### Required ACPI tables

The VMM must generate and provide:

|Table|Purpose              |Critical fields                    |
|-----|---------------------|-----------------------------------|
|RSDP |Entry point          |XSDT pointer, revision             |
|XSDT |Table directory      |Pointers to all tables             |
|FADT |Fixed hardware       |DSDT pointer, PM registers, SCI IRQ|
|DSDT |Device definitions   |Complete AML namespace             |
|MADT |Interrupt controllers|LAPIC entries, IOAPIC, overrides   |
|MCFG |PCIe config          |ECAM base address                  |
|HPET |Timer                |Base address (`0xFED00000`)        |
|FACS |Firmware control     |Hardware signature, wake vector    |

### table-loader implementation

A Rust implementation would define:

```rust
enum LoaderCommand {
    Allocate { file: String, align: u32, zone: Zone },
    AddPointer { dest_file: String, src_file: String, offset: u32, size: u8 },
    AddChecksum { file: String, offset: u32, start: u32, length: u32 },
    WritePointer { dest_file: String, src_file: String, dst_offset: u32, src_offset: u32, size: u8 },
}
```

Each command must be serialized to the 128-byte structure format. The sequence matters: ALLOCATE commands for all blobs must come first, followed by ADD_POINTER and ADD_CHECKSUM commands.

### Leveraging existing work

FreeBSD bhyve has implemented fw_cfg support in `usr.sbin/bhyve/qemu_fwcfg.c` and table-loader handling in `usr.sbin/bhyve/qemu_loader.c`. These changes were synced to illumos. The rust-vmm `acpi_tables` crate provides Rust-native ACPI table generation that Cloud Hypervisor uses, potentially suitable for Propolis. 

-----

## Alternative approaches for VMMs without fw_cfg

### Cloud Hypervisor’s direct RSDP placement

Cloud Hypervisor places the RSDP at a fixed guest address `0xa0000` and SMBIOS at `0xf0000`.  OVMF includes `CloudHvAcpi.c` that detects Cloud Hypervisor via the PCI Host Bridge Device ID and scans these fixed addresses instead of using fw_cfg.   This approach is already merged upstream in EDK2 and proven in production. As of Cloud Hypervisor v48.0 (September 2024), fw_cfg was added as an experimental feature for completeness.

The implementation complexity is **low to medium**—the VMM generates tables and places them at known addresses, while OVMF requires only a small detection module. The trade-off is inflexibility: fixed addresses may conflict with other firmware memory uses, and the VMM must match OVMF’s expectations exactly.

### Custom OVMF builds

Building OVMF with hardcoded tables requires reverting to **edk2-stable202105** or earlier, or maintaining patches that force `InstallOvmfFvTables()` instead of `InstallQemuFwCfgTables()`.  The `OvmfPkg/Bhyve/` platform variant retains bhyve-specific code that searches for RSDP at `BHYVE_ACPI_PHYSICAL_ADDRESS` (`0xf2400`). 

This provides full control but requires maintaining a custom firmware fork. Static tables cannot reflect dynamic VM configurations—CPU count, memory topology, and device changes require firmware rebuilds.

### bhyve’s dual-source approach

FreeBSD bhyve supports two modes: with the `-A` flag, bhyve generates ACPI tables dynamically; without it, OVMF’s built-in tables are used. The `acpi_tables_in_memory` configuration option controls fw_cfg exposure.  This flexibility creates potential for mismatches (e.g., COM port configuration differences between VMM and firmware tables).

### Using coreboot with UEFI payload

coreboot initializes hardware and generates ACPI tables, storing them in CBMEM.  The EDK2 `UefiPayloadPkg` parses coreboot tables via `CbParseLib.c`, extracting ACPI and SMBIOS for installation.  This approach requires building both coreboot and the UEFI payload, adding complexity but eliminating fw_cfg dependencies.

### SeaBIOS for legacy guests

SeaBIOS can generate its own ACPI tables or load them from QEMU via fw_cfg. However, since SeaBIOS 20220301, legacy built-in table generation was removed. For legacy BIOS guests that don’t require UEFI, SeaBIOS with fw_cfg remains an option, but modern workloads increasingly require UEFI features.

-----

## Conclusion: Implementation paths forward

For VMM developers facing the OVMF ACPI table requirement, three practical paths exist:

**Full fw_cfg implementation** provides maximum compatibility with the QEMU ecosystem and supports dynamic configuration, hotplug, and all modern OVMF features. The implementation requires approximately 500-1000 lines of code for the device and table-loader, plus ACPI table generation logic. FreeBSD bhyve’s implementation serves as a reference.

**Cloud Hypervisor’s direct placement model** offers the lowest implementation barrier for VMMs targeting modern EDK2. The approach is already upstream, requires minimal OVMF modifications, and works for static configurations. It lacks hotplug support and flexibility for dynamic topologies.

**Custom OVMF builds** work for controlled environments where VM configuration is fixed. Maintaining a firmware fork adds ongoing maintenance burden and limits access to upstream security fixes and features.

For Propolis specifically, implementing fw_cfg with table-loader support represents the most sustainable path, aligning with the FreeBSD bhyve changes already synced to illumos  and enabling full compatibility with current and future OVMF versions. The rust-vmm `acpi_tables` crate can provide the table generation foundation,  while the fw_cfg device implementation follows well-documented specifications available in QEMU’s `docs/specs/fw_cfg.rst`.