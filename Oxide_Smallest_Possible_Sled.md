# Smallest Possible Oxide Sled

## Simplest Possible Sled Setup for Oxide Computer Rack

Based on the provided Oxide Rack Specifications, the smallest possible sled setup—if only one sled is used—would be as follows:

**Processor**
- 1 × AMD EPYC 7713P
- 64 cores, 128 threads per sled[1]

**Memory (DRAM)**
- Minimum: 512 GiB (using 16 x DDR4 DIMM slots)[1]

**Storage**
- Minimum: 10 x 3.2 TB NVMe drives (totaling 32 TB raw storage; the spec lists "8 - 32 TiB" as the per-sled storage range, so 8 TB is likely the minimum supported, but the listed configuration is 10 x 3.2 TB = 32 TB)[1]

**Network Connectivity**
- 2 × 100 GbE per sled[1]

### Summary Table

| Component | Minimum Configuration (1 Sled) |
|---------------|------------------------------------------|
| Processor | 1 × AMD EPYC 7713P (64 cores, 128 threads)|
| Memory | 512 GiB DRAM |
| Storage | 8 TiB (minimum listed), up to 32 TiB |
| Network | 2 × 100 GbE |

To operate a single Oxide Computer sled, the minimum set of required components—based on the official specifications—is as follows:

- **Processor:**
1 × AMD EPYC 7713P CPU (64 cores, 128 threads)[1][2].

- **Memory:**
At least 512 GiB DDR4 DRAM (using the available 16 DIMM slots)[1][2].

- **Storage:**
At least 8 TiB NVMe storage (the minimum supported per sled)[1].

- **Networking:**
2 × 100 GbE network connections[1][2].

- **Motherboard/System Board:**
Includes the CPU socket, DIMM slots, NVMe bays, networking interfaces, hardware root-of-trust, and embedded service processor (replaces traditional BMC)[2].

- **Chassis:**
The sled enclosure itself, designed to be hot-pluggable into the rack cubby[2].

**Summary List of Minimum Components for One Sled:**
- 1 CPU (AMD EPYC 7713P)
- 16 DDR4 DIMM slots, with at least 512 GiB populated
- 10 NVMe bays, with at least enough drives to reach 8 TiB total storage
- 2 × 100 GbE NICs (integrated)
- Motherboard/system board (with root-of-trust and service processor)
- Sled chassis/enclosure

**Note:**
- Power is supplied via the rack’s DC busbar and not by a local power supply in the sled[5].
- The minimum configuration assumes only the essential hardware to boot and operate a single sled according to Oxide’s published requirements.

This is the smallest set of components needed for a single Oxide sled to function in the rack[1][2][5].

#### Sources
[1 Oxide-Rack-Specifications-20250217.pdf ](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/49592179/789ab338-90b7-4640-8b69-a93309ad4204/Oxide-Rack-Specifications-20250217.pdf)
[2 Introduction / Guides / Oxide ](https://docs.oxide.computer/guides/introduction
[3 Hypervisor and Storage / Guides / Oxide ](https://docs.oxide.computer/guides/architecture/os-hypervisor-storage)
[457 - Control plane sled lifecycle / RFD / Oxide ](https://457.rfd.oxide.computer
[5 How Oxide Created a Cloud Server by Stripping Components, Wires ... ](https://www.hpcwire.com/2023/11/01/how-oxide-created-a-cloud-server-by-stripping-components-wires-cables-and-chips/)
[6 Omicron: Oxide control plane - GitHub ](https://github.com/oxidecomputer/omicron
[7 Building Big Systems with Remote Hardware Teams - Oxide Computer ](https://oxide.computer/blog/building-big-systems-with-remote-hardware-teams)
[8 Oxide Computer Company ](https://oxide.computer)
[9 The Cloud Computer / Oxide ](https://oxide.computer/blog/the-cloud-computer)
[10 Startups on hard mode: Oxide. Part 1: Hardware ](https://newsletter.pragmaticengineer.com/p/oxide)
[11 System / Release Notes / Oxide ](https://docs.oxide.computer/release-notes)


**Conclusion:**
The smallest possible Oxide sled setup, if only one sled is installed, would have 1 AMD EPYC 7713P processor, 512 GiB DRAM, 8 TiB NVMe storage, and dual 100 GbE network connectivity[1].


#### Other resources & links
- [Oxide CDS Usage Breakdown](https://book.univrs.io/markd/oxide_cds_usage_breakdown)
- [oxide CDS Usage v2](https://book.univrs.io/markd/oxide_cds_v2)
- [Oxide Innovation](https://book.univrs.io/markd/oxide_innovations)
- [Oxide OS+Hardware ](https://book.univrs.io/markd/oxide_os-hardware)
- [Oxide Rack Customers](https://book.univrs.io/markd/oxide_rack_customers)
- [Oxide Single AMD EPYC 7713P](https://book.univrs.io/markd/oxide_single_amd_epyc_7713p_sled)
- [Oxide Smallest Bang$ ](https://book.univrs.io/markd/oxide_smallest_possible_sled)
- [Oxide Syndrom ](https://book.univrs.io/markd/oxide_syndrome)

### [Connect: Join Univrs.io Discord](https://discord.gg/pXwH6rQcsS)
- [Univrs Patreon](https://wwww.patreon.com/univrs)
- [Univrs.io](https://univrs.io)
- [https://ardeshir.io](https://ardeshir.io)
- [https://hachyderm.io/@sepahsalar](https://hachyderm.io/@sepahsalar)
- [https://github.com/ardeshir](https://github.com/ardeshir)
- [https://medium.com/@sepahsalar](https://medium.com/@sepahsalar)
- [https://www.linkedin.com/in/ardeshir](https://www.linkedin.com/in/ardeshir)
- [https://sepahsalar.substack.com/](https://sepahsalar.substack.com/)
- [LinkTree @Sepahsalar](https://linktr.ee/Sepahsalar) 
- [Univrs MetaLabel](https://unvirs.metalabel.com)
