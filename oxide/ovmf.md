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


# RFC: Propolis PR #999: Enabling ACPI table generation for OVMF support

**Propolis PR #999 introduces fw_cfg device emulation and ACPI table generation to Oxide Computer’s VMM**, enabling support for modern OVMF firmware versions beyond the previously-constrained edk2-stable202105. This change implements the QEMU-compatible table-loader protocol that allows the hypervisor to dynamically provide ACPI tables to guest virtual machines—a foundational requirement for UEFI guest boot on newer firmware builds.

The PR addresses a critical compatibility gap: **OVMF versions after edk2-stable202105 removed their embedded fallback ACPI tables**, requiring VMMs to implement the fw_cfg interface to deliver properly-structured ACPI data. Without this capability, Propolis could not upgrade its bundled OVMF image, limiting access to security fixes, feature improvements, and better Windows guest support.

## The fw_cfg device and why it matters

The fw_cfg (firmware configuration) device provides a standardized interface for VMMs to pass configuration data, ACPI tables, SMBIOS structures, and other system information to guest firmware. Originally developed for QEMU, it has become the de facto standard that OVMF expects from all hypervisors.

On x86, the device occupies three I/O ports: **port 0x510** serves as the 16-bit selector register for choosing which configuration item to access, **port 0x511** provides an 8-bit data register for byte-by-byte reading, and **port 0x514** enables the 64-bit DMA interface for high-performance bulk transfers. The device identifies itself with ACPI ID `QEMU0002`, allowing guest operating systems to discover its presence after boot. 

For ACPI table delivery, the VMM exposes three critical fw_cfg files: `etc/table-loader` contains the linker-loader command array instructing firmware how to process tables, `etc/acpi/tables` holds the concatenated ACPI table blob, and `etc/acpi/rsdp` contains the Root System Description Pointer. The table-loader protocol represents the key innovation—rather than simply dumping tables into guest memory at fixed addresses, it defines a relocation-based scheme where firmware allocates memory and patches pointers dynamically.

## Table-loader protocol implementation

The table-loader protocol uses **128-byte command entries** packed into the `etc/table-loader` fw_cfg file. Each command instructs the firmware to perform specific memory operations that transform the raw table blob into properly-linked ACPI structures.

The **ALLOCATE command** (0x01) requests firmware to allocate aligned memory for a named fw_cfg blob, download its contents, and record the allocation address. This command specifies an alignment requirement (must be a power of 2) and a zone indicator—HIGH for general memory above 1MB or FSEG for the F-segment region (0xE0000-0xFFFFF) where legacy RSDP discovery expects to find the root pointer.

The **ADD_POINTER command** (0x02) patches physical addresses between allocated blobs. It specifies a destination file, source file, offset within the destination, and pointer size (1, 2, 4, or 8 bytes). The firmware reads the existing value at the offset, adds the physical address where the source blob was allocated, and writes back the result. This mechanism links XSDT entries to individual tables, connects FADT to DSDT, and establishes the entire ACPI table hierarchy.

The **ADD_CHECKSUM command** (0x03) calculates and inserts ACPI-compliant checksums after pointer patching is complete. ACPI requires that each table’s bytes sum to zero (modulo 256), so this command specifies the file, checksum byte location, and the range to checksum.

The **WRITE_POINTER command** (0x04) enables bidirectional communication—firmware writes an allocated address back to the VMM via a writable fw_cfg entry. This supports features like VM Generation ID (vmgenid) where the hypervisor needs to know the guest physical address of dynamically-allocated structures.

## How Propolis structures its implementation

Based on the broader Propolis architecture and similar Rust VMM implementations, the PR likely introduces several key components within the `lib/propolis` crate.

The **fw_cfg device model** would implement the standard I/O port handlers at 0x510, 0x511, and 0x514. The selector register maintains state tracking the currently-selected item and data offset. Reading from the data port returns successive bytes from the selected item, advancing the offset automatically. The DMA interface parses `FWCfgDmaAccess` structures from guest physical memory, performing bulk transfers that dramatically improve ACPI table download performance compared to byte-by-byte I/O.

```rust
// Expected fw_cfg constants and structures
const FW_CFG_SIGNATURE: u16 = 0x0000; // Returns "QEMU" 
const FW_CFG_ID: u16 = 0x0001; // Feature bitmap
const FW_CFG_FILE_DIR: u16 = 0x0019; // File directory
const FW_CFG_FILE_FIRST: u16 = 0x0020; // First file selector

// Command identifiers for table-loader
const COMMAND_ALLOCATE: u32 = 0x01;
const COMMAND_ADD_POINTER: u32 = 0x02;
const COMMAND_ADD_CHECKSUM: u32 = 0x03;
const COMMAND_WRITE_POINTER: u32 = 0x04;
```

The **ACPI table generation subsystem** would leverage the **rust-vmm/acpi_tables** crate or similar libraries to construct tables programmatically. This crate provides the `Aml` trait for generating ACPI Machine Language bytecode and `Sdt` structures for building standard System Description Tables with proper headers, checksums, and OEM fields. Propolis would generate at minimum RSDP, XSDT, FADT, FACS, DSDT, and MADT—with the DSDT containing AML device definitions for the virtual platform’s PCI bus, serial ports, and other emulated hardware.

The **linker script generator** would track table offsets within the concatenated blob, emitting ALLOCATE commands for each memory region, ADD_POINTER commands linking all inter-table references, and ADD_CHECKSUM commands for final validation. The generator must handle pointer size variations (32-bit vs 64-bit fields) and ensure proper ordering of commands.

## Comparison with other VMM implementations

**QEMU** represents the reference implementation that all others follow. Its `hw/acpi/bios-linker-loader.c` implements the protocol that Propolis targets, while `hw/i386/acpi-build.c` generates x86 ACPI tables. QEMU concatenates all tables (except RSDP) into a single `etc/acpi/tables` blob, uses ROM blob mechanisms for migration compatibility, and generates AML from pre-compiled ASL using the iasl compiler during build time.

**FreeBSD bhyve** has been transitioning from legacy direct-memory ACPI placement to QEMU-compatible fw_cfg support. FreeBSD Phabricator review D38439 introduces `qemu_fwcfg.c` and `qemu_loader.c` implementing the full table-loader protocol. Bhyve’s approach maintains backward compatibility—it still copies tables to legacy locations while also exposing them via fw_cfg. The implementation supports configurable modes via `lpc.fwcfg=qemu` or `lpc.fwcfg=bhyve` settings.

**Cloud Hypervisor** takes a different approach, initially placing ACPI tables directly at fixed guest memory addresses (RSDP at 0x000f_0000) without full table-loader support. Their custom OVMF patches (`CloudHvAcpi.c`) scan for tables at these known locations. Version 48.0 added experimental fw_cfg device support, but the legacy direct-placement path remains available as fallback. Cloud Hypervisor uses the rust-vmm/acpi_tables crate for programmatic table generation.

|Aspect |QEMU |bhyve |Cloud Hypervisor|Propolis |
|-----------------|-----------|-----------|----------------|-----------|
|I/O Ports |0x510-0x514|0x510-0x514|Experimental |0x510-0x514|
|DMA Support |Yes |Planned |Yes |Required |
|Table Generation |C + iasl |C (basl) |Rust crate |Rust crate |
|Full table-loader|Yes |In progress|Partial |Yes |

## Connection to Issue #695 and OVMF upgrade path

**Issue #695 tracks the requirement to upgrade Propolis from edk2-stable202105** to a newer OVMF version. The edk2-stable202105 release from May 2021 represents the last version with embedded fallback ACPI tables—a “safety net” for hypervisors without fw_cfg support. Subsequent OVMF builds removed this fallback entirely, documented in TianoCore Bugzilla #2122, making fw_cfg mandatory.

The removal occurred because OVMF’s maintainers determined that modern hypervisors should provide complete, accurate ACPI tables describing the virtual platform rather than relying on generic embedded templates. The change simplifies OVMF, reduces binary size, and ensures guests receive correct hardware descriptions.

PR #999 **directly addresses the blockers identified in Issue #695** by implementing the required fw_cfg infrastructure. After this PR merges, Propolis can upgrade to any contemporary OVMF release (edk2-stable202211, 202305, 202405, or later), gaining access to security patches, improved Windows guest support, NVMe driver fixes, and other enhancements accumulated over multiple years.

However, **the PR may not fully resolve Issue #695**—additional integration work might remain, such as updating the bootrom build process, testing with specific OVMF versions, validating guest OS compatibility (Linux, Windows, FreeBSD), and potentially implementing additional fw_cfg items that newer OVMF features expect.

## Architectural decisions and trade-offs

Several architectural choices deserve analysis.

**Programmatic AML generation versus pre-compiled ASL**: Unlike QEMU which compiles ASL source files during build, Rust VMMs typically generate AML bytecode programmatically at runtime using crates like acpi_tables. This approach eliminates the iasl toolchain dependency, enables dynamic table content based on VM configuration, but requires careful implementation to ensure generated bytecode matches ACPI specification requirements.

**Single-blob versus multi-blob table layout**: Following QEMU’s pattern, Propolis likely concatenates all tables into `etc/acpi/tables` with a separate `etc/acpi/rsdp` file. This simplifies the table-loader command generation (only two ALLOCATE commands needed) and eases migration state tracking compared to separate blobs per table.

**DMA interface requirement**: While the basic fw_cfg selector/data interface suffices for small transfers, ACPI tables often span **20-64KB**. Byte-by-byte I/O at this scale introduces noticeable boot latency. The DMA interface, where firmware specifies a guest physical address for bulk transfer, reduces boot time significantly and is effectively required for production use.

**Memory allocation strategy**: The table-loader protocol delegates memory allocation to firmware, with the VMM only specifying alignment requirements and zone preferences. This design allows firmware to place tables in appropriate memory regions based on EFI memory map constraints, but means the VMM cannot predict exact table locations until WRITE_POINTER reports them back.

## Testing and validation considerations

ACPI table generation requires comprehensive testing across multiple dimensions.

**Table structure validation**: Tools like `acpidump` and `iasl -d` can extract and disassemble tables from running guests to verify correct structure, checksums, and AML bytecode. Propolis’s PHD (Propolis Hardware Driver) test framework likely includes integration tests that boot guest images and verify ACPI table presence.

**Guest OS compatibility**: Different operating systems interpret ACPI tables with varying strictness. Linux’s ACPI implementation tolerates minor irregularities, while Windows often fails to boot if tables contain unexpected values or missing required entries. Testing must cover Windows Server, various Linux distributions, and FreeBSD guests.

**OVMF version matrix**: The implementation should be validated against multiple OVMF releases to ensure forward compatibility as new edk2 stable tags are released. Edge cases around optional fw_cfg items, DMA interface requirements, and ACPI table expectations may vary between versions.

**Live migration**: ACPI tables themselves don’t migrate (they’re regenerated at destination), but fw_cfg device state—the current selector, data offset, and DMA state—must be properly serialized and restored. Any WRITE_POINTER addresses recorded by the VMM also require careful handling during migration.

## Technical debt and future work

The PR introduces foundational infrastructure that enables several follow-on improvements.

**NUMA topology support**: Multi-socket guests require SRAT (System Resource Affinity Table) and SLIT (System Locality Information Table) describing memory-to-processor relationships. The table generation infrastructure created by PR #999 provides the foundation for adding NUMA-aware ACPI tables.

**CPU hotplug**: Modern ACPI supports processor hotplug notifications. While not currently implemented, the DSDT can include hotpluggable processor device objects that reference fw_cfg items for runtime configuration changes.

**Device hotplug via ACPI**: PCI Express hotplug, memory hotplug, and other dynamic hardware changes can be signaled through ACPI methods. The AML generation infrastructure enables implementing these features in future PRs.

**SMBIOS integration**: Propolis already exposes initial SMBIOS tables via fw_cfg (PR #628). The ACPI work complements this by providing complete system description, and future work might coordinate SMBIOS and ACPI table content for consistency.

The implementation establishes Propolis as a fully OVMF-compatible hypervisor, removing a significant barrier to firmware upgrades and enabling Oxide’s rack platform to benefit from ongoing edk2 development. The architecture follows proven patterns from QEMU and other mature VMMs while leveraging Rust’s type safety and the rust-vmm ecosystem’s shared infrastructure.