# AMD, ARM & why RISC-V is the future! 

**AMD** is one of the main manufacturers of x86-64 processors, not ARM.

**ARM is a completely different architecture** - it uses its own ARM instruction set, which is separate from x86-64.

## Main x86-64 Manufacturers:

1. **AMD (Advanced Micro Devices)** - Actually created the x86-64 instruction set (originally called AMD64) as a 64-bit extension of Intel’s x86 architecture. Their processor lines include:

- Ryzen (desktop/laptop)
- EPYC (server)
- Threadripper (high-end desktop)

1. **Intel** - Also manufactures x86-64 processors (they call it Intel 64 or x64). Their lines include:

- Core series (i3, i5, i7, i9)
- Xeon (server)

1. **Other manufacturers** (smaller market presence):

- VIA Technologies (Zhaoxin) - Chinese x86-64 processors
- Some other Chinese manufacturers working on x86-64 compatibility

**The key distinction:** ARM and x86-64 are competing, incompatible architectures. Software compiled for x86-64 won’t run natively on ARM processors and vice versa (though translation/emulation is possible, like Apple’s Rosetta 2).​​​​​​​​​​​​​​​​

# ARM Architecture

## Background:

**ARM (Advanced RISC Machine, originally Acorn RISC Machine)** was created by ARM Holdings (originally Acorn Computers) in the 1980s. Unlike AMD/Intel, **ARM Holdings doesn’t manufacture chips** - they license their architecture designs to other companies who then manufacture the processors.

## ARM Instruction Set:

- Based on RISC (Reduced Instruction Set Computing) principles
- Multiple versions: ARMv7 (32-bit), ARMv8 (64-bit, also called ARM64 or AArch64), ARMv9 (latest)
- Known for power efficiency, making it dominant in mobile devices

## Main ARM Chip Manufacturers:

1. **Apple** - Designs their own ARM-based chips:

- M-series (M1, M2, M3, M4) for Macs
- A-series (A17, A18) for iPhones/iPads

1. **Qualcomm** - Major mobile chip maker:

- Snapdragon series (smartphones, tablets, laptops)

1. **Samsung** - Both manufactures and designs:

- Exynos processors (smartphones, tablets)

1. **MediaTek** - Major mobile chip maker:

- Dimensity series (smartphones)
- Used widely in mid-range Android devices

1. **Nvidia** - ARM-based chips:

- Tegra (automotive, embedded)
- Grace (server processors)

1. **Amazon** - AWS Graviton processors (server/cloud)
1. **Ampere Computing** - ARM server processors
1. **Marvell, Broadcom** - Networking and embedded systems

-----

# RISC-V Architecture

## Background:

**RISC-V** (pronounced “risk five”) was created at UC Berkeley in 2010 as an **open-source, royalty-free instruction set architecture**. Unlike ARM and x86-64, anyone can implement RISC-V without licensing fees, making it attractive for research, education, and commercial use.

## RISC-V Instruction Set:

- Based on RISC principles (like ARM)
- Modular design with base instruction set + optional extensions
- Comes in 32-bit (RV32), 64-bit (RV64), and 128-bit (RV128) variants
- Open standard maintained by RISC-V International

## Main RISC-V Chip Manufacturers:

1. **SiFive** - Leading commercial RISC-V chip designer:

- Performance cores for embedded/IoT
- Intelligence series processors

1. **StarFive** - Chinese company:

- JH7110 (used in development boards)
- Focus on edge computing

1. **Alibaba/T-Head** - Chinese tech giant:

- Xuantie series processors
- Used in various embedded applications

1. **Espressif** - IoT chip maker:

- ESP32-C and ESP32-H series (microcontrollers)

1. **Andes Technology** - Taiwanese company:

- Embedded and IoT processors

1. **Western Digital** - Uses RISC-V in storage controllers
1. **Google** - Developing RISC-V cores for internal use
1. **Qualcomm, Nvidia, Samsung** - All investing in RISC-V development

## Key Differences Summary:

- **x86-64**: Proprietary (AMD/Intel oligopoly), dominant in desktops/servers, high performance but power-hungry
- **ARM**: Licensed architecture, dominant in mobile/embedded, power-efficient, growing in laptops/servers
- **RISC-V**: Open-source/free, emerging architecture, popular in embedded/IoT, China is heavily investing due to independence from US tech​​​​​​​​​​​​​​​​

# RISC-V Deep Dive for Open Hardware Development

## What Makes RISC-V Revolutionary for Open Hardware

### The Open Standard Philosophy

Unlike ARM (licensed) or x86-64 (proprietary), **RISC-V specifications are freely available** under a Creative Commons license. This means:

- **No royalties** to implement
- **No licensing fees** to manufacture
- **No restrictions** on modifications
- **Complete transparency** - all specifications are public

This is transformative because traditionally, CPU architectures have been controlled by a few companies with significant barriers to entry.

-----

## RISC-V ISA Architecture Deep Dive

### 1. **Modular Design Philosophy**

RISC-V uses a **base + extensions** model:

**Base Integer Instruction Sets:**

- **RV32I** - 32-bit base (40+ instructions)
- **RV64I** - 64-bit base
- **RV128I** - 128-bit base (future-proofing)

**Standard Extensions (Optional):**

- **M** - Integer Multiplication and Division
- **A** - Atomic instructions (for multi-threading)
- **F** - Single-precision floating-point
- **D** - Double-precision floating-point
- **C** - Compressed instructions (16-bit, code density)
- **V** - Vector operations
- **B** - Bit manipulation
- **P** - Packed SIMD
- **Q** - Quad-precision floating-point

**Common Combinations:**

- **RV32GC** = RV32IMAFD + C (general purpose with compressed)
- **RV64GC** = RV64IMAFD + C (64-bit general purpose)

This modularity lets you build **exactly the processor you need** - from tiny microcontrollers to high-performance servers.

### 2. **Register Architecture**

**32 integer registers:**

- `x0` - Hardwired to zero (very useful for common operations)
- `x1` - Return address
- `x2` - Stack pointer
- `x3` - Global pointer
- `x4` - Thread pointer
- `x5-x7, x28-x31` - Temporary registers
- `x8-x9, x18-x27` - Saved registers
- `x10-x17` - Function arguments/return values

**32 floating-point registers** (if F/D extensions enabled):

- `f0-f31`

**Clean, simple design** - easier to implement in hardware than x86’s complex register history.

### 3. **Instruction Formats**

RISC-V has **only 6 base instruction formats** (vs x86’s hundreds):

```
R-type: Register-register operations
I-type: Immediate and load operations
S-type: Store operations
B-type: Branch operations
U-type: Upper immediate operations
J-type: Jump operations
```

All instructions are **fixed-width 32-bit** (or 16-bit with C extension), making decode logic simpler and faster than x86’s variable-length instructions.

### 4. **Privilege Levels**

RISC-V defines **3 privilege modes:**

- **M-mode** (Machine) - Highest privilege, always present
- **S-mode** (Supervisor) - For operating systems
- **U-mode** (User) - For applications

This enables proper OS/application separation while remaining simple.

-----

## Open Hardware Development Ecosystem

### **1. Open Source Cores (HDL Implementations)**

You can download, modify, and manufacture these:

**High-Performance Cores:**

- **BOOM (Berkeley Out-of-Order Machine)** - Superscalar, out-of-order
  - Written in Chisel (Scala-based HDL)
  - Competitive with commercial ARM cores
- **Rocket Chip** - In-order, configurable
  - Also from Berkeley, mature and widely used
  - Basis for many commercial implementations
- **CVA6 (formerly Ariane)** - Application processor
  - 6-stage pipeline, MMU support
  - Linux-capable

**Mid-Range Cores:**

- **PicoRV32** - Small, efficient (Verilog)
  - Great for FPGAs and embedded
- **VexRiscv** - Configurable soft-core (SpinalHDL)
  - Very flexible, FPGA-friendly

**Microcontroller Cores:**

- **Ibex** (formerly Zero-riscy) - 2-stage pipeline
  - From lowRISC, very small
- **SweRV** - From Western Digital
  - High-performance embedded

**GPU/Accelerator Projects:**

- **Ventana Micro** - High-performance designs
- **PULP Platform** - Parallel Ultra-Low-Power

### **2. Hardware Description Languages**

**Traditional:**

- **Verilog/SystemVerilog** - Most cores available in these
- **VHDL** - Some implementations

**Modern/High-Level:**

- **Chisel** (Constructing Hardware in Scala Embedded Language)
  - Used by Berkeley projects (Rocket, BOOM)
  - Enables parametric, generator-based design
  - Compiles to Verilog
- **SpinalHDL** - Another high-level HDL
  - VexRiscv written in this
- **Bluespec** - High-level synthesis language

### **3. Development Tools (All Open Source)**

**Compilers & Toolchains:**

- **GCC** - Full RISC-V support (upstream)
- **LLVM/Clang** - Full RISC-V support
- **Rust** - Tier 2 support for RISC-V
- **Go, Python, Java** - All support RISC-V

**Simulators:**

- **Spike** - Official RISC-V ISA simulator
- **QEMU** - Full system emulation
- **Verilator** - Fast HDL simulator (for core development)
- **Renode** - Multi-node simulation

**Operating Systems:**

- **Linux** - Full upstream support
- **FreeBSD** - Full support
- **Zephyr RTOS** - For embedded
- **FreeRTOS** - For microcontrollers
- **seL4** - Formally verified microkernel

**Debugging:**

- **OpenOCD** - Debug interface
- **GDB** - Full RISC-V support

-----

## Design Workflow for Open Hardware Development

### **Phase 1: Architecture Selection**

1. **Choose your base ISA:**

- RV32I for microcontrollers
- RV64I for application processors

1. **Select extensions:**

- Add M if you need multiplication
- Add A for atomic operations (multi-core)
- Add F/D for floating-point
- Add C for code density (saves memory)

1. **Example configurations:**

- IoT device: RV32IMC
- Embedded control: RV32IMAC
- Linux system: RV64GC
- DSP application: RV32IMFV

### **Phase 2: Core Selection/Development**

**Option A: Use Existing Core**

```
1. Pick a core (e.g., VexRiscv, PicoRV32)
2. Configure parameters:
   - Pipeline depth
   - Cache sizes
   - Branch prediction
   - Extensions to include
3. Synthesize to FPGA or ASIC
```

**Option B: Design Your Own**

```
1. Study RISC-V spec (freely available)
2. Choose HDL (Chisel recommended for flexibility)
3. Implement:
   - Instruction fetch
   - Decode
   - Execute
   - Memory access
   - Write-back
4. Verify against compliance tests
```

### **Phase 3: SoC Integration**

Add peripherals using **standard buses:**

- **TileLink** - Berkeley’s coherent interconnect
- **AXI4** - ARM’s standard (widely supported)
- **Wishbone** - Open-source bus standard
- **APB** - Simple peripheral bus

**Example SoC Structure:**

```
RISC-V Core(s)
    ├── L1 Instruction Cache
    ├── L1 Data Cache
    └── TileLink/AXI Bus
        ├── L2 Cache (optional)
        ├── Memory Controller (DDR)
        ├── UART
        ├── SPI
        ├── GPIO
        ├── Timers
        └── Custom accelerators
```

### **Phase 4: FPGA Prototyping**

**Popular FPGA Platforms:**

- **Xilinx (AMD):**
  - Artix-7 (lower-cost)
  - Kintex/Virtex (high-performance)
  - Boards: Arty, Nexys, etc.
- **Intel (Altera):**
  - Cyclone V
  - Stratix series
- **Lattice:**
  - iCE40 (small, open toolchain)
  - ECP5 (mid-range, open toolchain)

**Open Source FPGA Tools:**

- **Yosys** - Synthesis
- **nextpnr** - Place and route
- **IceStorm** - Lattice iCE40 toolchain
- **Project Trellis** - Lattice ECP5

### **Phase 5: Verification**

**Compliance Testing:**

- **riscv-tests** - Official compliance suite
- **riscv-torture** - Random test generator
- **riscv-dv** - SystemVerilog UVM framework

**Formal Verification:**

- **Symbolic execution** to prove correctness
- Many academic projects in this space

-----

## Manufacturing Options

### **1. FPGA Deployment**

- **Pros:** Fast iteration, reconfigurable, no fab costs
- **Cons:** Slower, more power-hungry than ASIC
- **Use cases:** Prototyping, low-volume production, specialized computing

### **2. ASIC Manufacturing**

**Shuttle Runs (Multi-Project Wafers):**

- **SkyWater 130nm** - Open PDK, Google-sponsored
- **GlobalFoundries** - Various processes
- **TSMC** - Through university programs

**Tape-out Services:**

- **Efabless** - Coordinates open-source tapeouts
- **ChipIgnite** - Programs for free/subsidized fabrication

**Open PDKs (Process Design Kits):**

- **SkyWater SKY130** - 130nm, fully open
- **Google/SkyWater partnership** - Making ASIC accessible

**Full Open-Source ASIC Flow:**

```
HDL (Verilog/Chisel)
    ↓
OpenLane/OpenROAD (synthesis, place & route)
    ↓
GDSII (chip layout)
    ↓
Fabrication (SkyWater/other)
```

### **3. Hybrid Approaches**

- **chiplet designs** - Mix RISC-V with other IP
- **FPGAs with hardened RISC-V** - Best of both worlds

-----

## Real-World Open Hardware Projects

### **Academic/Research:**

1. **Pulpissimo** - Parallel processing platform
1. **Ariane** - Application processor for HPC research
1. **OpenPiton** - Manycore research platform (1000+ cores)

### **Commercial (Open Source):**

1. **SiFive HiFive** boards - Development platforms
1. **BeagleV** - Linux-capable board (discontinued but inspired others)
1. **Milk-V** series - Low-cost RISC-V boards
1. **StarFive VisionFive** - Linux SBC

### **Embedded:**

1. **ESP32-C3/C6** - WiFi/BLE microcontrollers (Espressif)
1. **GD32VF103** - Microcontroller (GigaDevice)
1. **Kendryte K210** - Edge AI chip

-----

## Advantages for Open Hardware Development

### **Technical Benefits:**

1. **No Black Boxes** - Every aspect is transparent
1. **Customization** - Tailor to exact needs:

- Add custom instructions
- Remove unused features
- Optimize for specific workloads

1. **Security** - Can audit entire stack:

- No hidden backdoors
- Verifiable security properties
- Formal verification possible

1. **Education** - Perfect for learning:

- Complete specs available
- Many open implementations to study
- Active academic community

### **Business Benefits:**

1. **No Licensing Costs** - Especially important for:

- Startups
- Academic institutions
- Developing nations

1. **No Vendor Lock-in** - Can:

- Switch implementations
- Modify as needed
- Control your supply chain

1. **Future-Proof** - Standard won’t disappear or change arbitrarily

-----

## Challenges & Considerations

### **Current Limitations:**

1. **Ecosystem Maturity:**

- Less software than x86/ARM
- Fewer development tools (improving rapidly)
- Limited peripheral IP (growing)

1. **Performance Gap:**

- High-end RISC-V still behind Intel/AMD/Apple
- Catching up quickly (2-3 years behind)

1. **Fragmentation Risk:**

- Custom extensions can break compatibility
- Need discipline to maintain interoperability

1. **Manufacturing Access:**

- Advanced nodes (3nm, 5nm) still hard to access
- Open PDKs currently at older nodes (130nm, 180nm)

### **Best Practices:**

1. **Stick to Standard Extensions** when possible
1. **Use Established Cores** unless you have specific needs
1. **Contribute Back** to the community
1. **Plan for Verification** from day one
1. **Start with FPGA** before committing to ASIC

-----

## Getting Started: Practical Steps

### **Beginner Path:**

1. Get a **RISC-V development board** (SiFive HiFive, Milk-V)
1. Install **RISC-V toolchain** (riscv-gnu-toolchain)
1. Run **QEMU** or **Spike** simulators
1. Study **PicoRV32** or **VexRiscv** source code
1. Modify and simulate a simple core

### **Intermediate Path:**

1. **Deploy a core to FPGA** (Arty board + Rocket Chip)
1. **Add custom peripheral**
1. **Run Linux** on your FPGA
1. **Study Chisel** and Rocket Chip generator
1. **Create custom SoC**

### **Advanced Path:**

1. **Design custom instruction extensions**
1. **Implement multi-core system**
1. **Tape out ASIC** via Efabless/SkyWater
1. **Contribute to open-source cores**
1. **Formal verification** of your design

-----

## Resources

**Official:**

- [riscv.org](http://riscv.org) - Specifications, foundation
- [github.com/riscv](http://github.com/riscv) - Official repositories

**Learning:**

- “Computer Architecture: A Quantitative Approach” (Hennessy & Patterson)
- “The RISC-V Reader” (Patterson & Waterman)
- riscv-software-list on GitHub

**Communities:**

- RISC-V International members
- Forums, Reddit (r/RISCV)
- Conferences (RISC-V Summit, workshops)

-----

RISC-V represents a fundamental shift in how processors are designed and built. For the first time, **anyone** can design, manufacture, and sell a modern CPU architecture without permission or fees. This democratization of hardware design is similar to what Linux did for operating systems and what open-source did for software. The combination of open ISA + open cores + open tools + open PDKs creates an unprecedented opportunity for innovation in hardware.​​​​​​​​​​​​​​​​