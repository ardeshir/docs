## The Oxide Cloud Computer rack, 

When configured for maximum capacity (32 sleds), provides 3500 vCPUs available for guest VMs. To determine the total number of VMs allocatable per project (CNC, NA, Max), these resources are distributed.

Each of the three projects (CNC, NA, Max) can be allocated approximately 1166 vCPUs (3500 vCPUs / 3 projects). The total number of Virtual Machines (VMs) that can be allocated per project is contingent upon the specific vCPU requirement of each VM. For instance:
 * If VMs are configured with 1 vCPU, approximately 1166 VMs can be allocated per project.
 * If VMs are configured with 2 vCPUs, approximately 583 VMs can be allocated per project.
 * If VMs are configured with 4 vCPUs, approximately 291 VMs can be allocated per project.

The precise number of VMs will be determined by the tailored resource configuration (vCPU, memory, storage) assigned to meet the workload demands of each VM across the four environments (dev, test, UAT, prod) for every product.

## High-Performance Rack Configuration and Resource Allocation Strategy 🚀

To achieve the best possible performance and accommodate growth for each product (CNC, NA, and Max) with their respective dev, test, UAT, and prod environments, the following rack configuration and resource allocation strategy is recommended:

1. Optimal Rack Configuration
Select the 32 Compute Sleds configuration to maximize available resources. This provides:
 * Total Available vCPUs for VMs: 3500
 * Total Available Memory (DRAM) for VMs: 27.2 TiB (using the higher option for maximum performance)
 * Total Available NVMe Block Storage for VMs: 250 TiB
 * Total Network Switching Bandwidth (L3): 12.8 \text{ Tbit/s}

2. Per-Product Resource Pools
To ensure each of the three products (CNC, NA, Max) has sufficient resources for their four environments and future growth, the total rack resources should be divided equitably among them:
 * vCPUs per Product: Approximately 3500 / 3 \approx \textbf{1166 vCPUs}
 * Memory (DRAM) per Product: Approximately 27.2 \text{ TiB} / 3 \approx \textbf{9.07 TiB}
 * NVMe Block Storage per Product: Approximately 250 \text{ TiB} / 3 \approx \textbf{83.33 TiB}
This allocation provides a substantial dedicated resource pool for each product line.

3. Environment Resource Distribution (per Product)
Within each product's allocated resource pool (e.g., ~1166 vCPUs, ~9.07 TiB Memory, ~83.33 TiB NVMe), resources should be distributed across the four environments (dev, test, UAT, prod). A common practice, prioritizing production and pre-production stability and performance, would be:
 * Production (Prod): Allocate the largest share of resources (e.g., 40-50%). This environment requires the highest performance and availability for live customers.
 * User Acceptance Testing (UAT): Allocate a significant share (e.g., 25-30%). This environment should closely mirror production to ensure accurate testing.
 * Testing (Test): Allocate a moderate share (e.g., 15-20%) for quality assurance activities.
 * Development (Dev): Allocate a smaller share (e.g., 10-15%) for development and experimentation.
The exact percentages should be tailored to the specific needs, workload characteristics, and user base of each product and its environments.

4. VM Sizing and Allocation
 * VMs: The number of VMs per environment will depend on their individual sizing (vCPU, RAM, storage). For example, a product's production environment with an allocation of 583 vCPUs (50% of 1166) could host 291 VMs if each requires 2 vCPUs, or fewer, more powerful VMs.
 * Performance: Sizing should ensure that critical environments, especially production and UAT, are not oversubscribed in terms of vCPU, memory, or I/O to maintain optimal performance. The all-NVMe storage infrastructure provides high-speed block storage suitable for demanding applications.

5. Supporting Growth and Global Customers
This configuration provides a robust platform for growth:
 * Scalable Resources: The significant pools of vCPU, memory, and fast NVMe storage per product allow for scaling customer numbers and data volume.
 * High Network Throughput: The 12.8 \text{ Tbit/s} network bandwidth ensures that inter-VM communication and external traffic can be handled efficiently, crucial for globally accessed services. Each of the two network switches offers 6.4 \text{ Tbit/s} of bandwidth.
 * Flexibility: Resources can be dynamically re-allocated between environments within a product's pool as needs evolve (e.g., more resources for testing during a major release).
 * Hardware Foundation: Each compute sled is powered by an AMD EPYC 7713P processor with 64 cores, ensuring strong underlying compute capabilities. The system also features robust power delivery with up to two power shelves, each supporting redundant power supplies (5+1 or 3+3).

By adopting this top-tier rack configuration and strategic resource allocation, each product (CNC, NA, Max) will be well-equipped with the necessary compute, memory, storage, and network resources to configure its environments effectively and support a growing global customer base.

#### Other resources & links
- [Oxide CDS Usage Breakdown](https://book.univrs.io/markd/oxide_cds_usage_breakdown)
- [oxide CDS Usage v2](https://book.univrs.io/markd/oxide_cds_v2)
- [Oxide Innovation](https://book.univrs.io/markd/oxide_innovations)
- [Oxide OS+Hardware ](https://book.univrs.io/markd/oxide_os-hardware)
- [Oxide Rack Customers](https://book.univrs.io/markd/oxide_rack_customers)
- [Oxide Single AMD EPYC 7713P](https://book.univrs.io/markd/oxide_single_amd_epyc_7713p_sled)
- [Oxide Smallest Bang$ ](https://book.univrs.io/markd/oxide_smallest_possible_sled)
- [Oxide Syndrom ](https://book.univrs.io/markd/oxide_syndrome) 

### Connect: Join Univrs.io
- [Univrs.io Discord](https://discord.gg/pXwH6rQcsS)
- [Univrs Patreon](https://www.patreon.com/univrs)
- [Univrs.io](https://univrs.io)
- [https://ardeshir.io](https://ardeshir.io)
- [https://hachyderm.io/@sepahsalar](https://hachyderm.io/@sepahsalar)
- [https://github.com/ardeshir](https://github.com/ardeshir)
- [https://medium.com/@sepahsalar](https://medium.com/@sepahsalar)
- [https://www.linkedin.com/in/ardeshir](https://www.linkedin.com/in/ardeshir)
- [https://sepahsalar.substack.com/](https://sepahsalar.substack.com/)
- [LinkTree @Sepahsalar](https://linktr.ee/Sepahsalar) 
- [Univrs MetaLabel](https://univrs.metalabel.com)
