## Based on the Oxide rack specifications

Given CDS requirements, here is a detailed analysis and design recommendation for allocating virtual machines (VMs) across four environments (dev, test, UAT, prod) for three products (CNC, NA, Max), along with a performance-optimized solution to support global growth.

---

#### Oxide Rack Key Specifications (Per Rack)

- Maximum compute sleds: 32
- Each sled has:
  - 64 physical cores (AMD EPYC 7713P)
  - 512 GB to 1 TB DRAM (using 1 TB for max capacity)
  - NVMe storage: up to 10 x 3.2 TB drives per sled
- Total resources per full rack (32 sleds):
  - CPU cores: 32 x 64 = 2048 cores
  - Memory: 32 x 1 TB = 32 TB RAM (32,768 GB)
  - NVMe storage: ~250 TB total
- Network bandwidth: 12.8 Tbit/s
- Power draw: up to 15 kW per rack
- Custom hypervisor based on Bhyve/Illumos for VM management

---

## VM Resource Requirements per Product (Hypothetical)

| Product | vCPU per VM | RAM per VM (GB) |
|---------|-------------|-----------------|
| CNC     | 4           | 16              |
| NA      | 8           | 32              |
| Max     | 16          | 64              |

---

## Total VMs Per Product Per Environment

- Total vCPUs available: 2048 (2 vCPUs per physical core)
- Total RAM available: 32,768 GB

**Calculations:**

- For CNC:
  - Max VMs by CPU: 2048 / 4 = 512
  - Max VMs by RAM: 32,768 / 16 = 2048
  - Limiting factor: CPU → 512 VMs total
  - Per environment (4 environments): 512 / 4 = 128 VMs

- For NA:
  - Max VMs by CPU: 2048 / 8 = 256
  - Max VMs by RAM: 32,768 / 32 = 1024
  - Limiting factor: CPU → 256 VMs total
  - Per environment: 256 / 4 = 64 VMs

- For Max:
  - Max VMs by CPU: 2048 / 16 = 128
  - Max VMs by RAM: 32,768 / 64 = 512
  - Limiting factor: CPU → 128 VMs total
  - Per environment: 128 / 4 = 32 VMs

**Summary:**

| Product | Total VMs (all envs) | VMs per Environment |
|---------|----------------------|---------------------|
| CNC     | 512                  | 128                 |
| NA      | 256                  | 64                  |
| Max     | 128                  | 32                  |

---

## Designing for Growth and Performance

Assuming a growth factor of 2x for each product (doubling VM needs as customers grow globally):

| Product | Base VMs per Env | Growth VMs per Env | Total VMs per Env (base + growth) |
|---------|------------------|--------------------|-----------------------------------|
| CNC     | 128              | 256                | 384                               |
| NA      | 64               | 128                | 192                               |
| Max     | 32               | 64                 | 96                                |

To accommodate this growth within the same rack, resource allocation must be optimized:

### Recommendations for Performance and Scalability

- **Resource Partitioning:** Use Oxide's silo feature to isolate resources per product and environment, ensuring strict tenancy and resource guarantees.
- **Dynamic Resource Allocation:** Leverage Oxide's custom hypervisor and software stack to dynamically allocate CPU and memory resources based on workload demand, allowing burst capacity.
- **Storage Allocation:** Allocate NVMe storage proportionally to VM count and workload I/O needs, ensuring high throughput and low latency.
- **Network Configuration:** Utilize the 12.8 Tbit/s switching capacity to segregate traffic per product and environment, minimizing contention and maximizing throughput.
- **Power Management:** Use Oxide's power management capabilities to optimize power draw per sled, allowing the rack to operate efficiently under varying loads.
- **Future-Proofing:** Plan for DDR5 upgrades and AMD Turin processors to increase performance and capacity as Oxide releases new hardware.

---

## Final Notes

- The maximum VMs per environment per product are constrained primarily by CPU cores.
- Memory and storage are sufficient to support these VM counts with room for growth.
- Oxide's rackscale design integrates hardware and software tightly, enabling rapid deployment and management.
- For global growth, consider deploying multiple racks or hybrid cloud extensions as demand exceeds single rack capacity.

---

This design ensures each product (CNC, NA, Max) has dedicated, scalable environments (dev, test, UAT, prod) with sufficient resources to grow their customer base globally while maintaining high performance and operational efficiency.

---

**References:** Oxide rack specs and VM resource calculations based on provided PDF and code analysis[1][2][3].

Sources
[1] Oxide-Rack-Specifications-20250217.pdf https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/49592179/4b42cce1-9c77-4bfb-8353-f732afc9748b/Oxide-Rack-Specifications-20250217.pdf
[2] Oxide reimagines the DC rack as... a 2500-lb blade server? https://www.theregister.com/2024/02/16/oxide_3000lb_blade_server/
[3] Investing in Oxide: Unlocking Cloud Benefits for On-prem Data ... https://www.intelcapital.com/investing-in-oxide-unlocking-cloud-benefits-for-on-prem-data-centers/
[4] Key Concepts / Guides / Oxide https://docs.oxide.computer/guides/key-entities-and-concepts
[5] Row-Scale On-Premises Cloud Infrastructure from Oxide Computer https://futurumgroup.com/insights/row-scale-on-premises-cloud-infrastructure-from-oxide-computer/
[6] Introduction / Guides / Oxide https://docs.oxide.computer/guides/introduction
[7] Oxide on-prem cloud computer reinvents the server rack https://blocksandfiles.com/2023/10/31/oxide-on-prem-cloud-computer/
[8] Startup Oxide launches on-prem cloud computing rack system - DCD https://www.datacenterdynamics.com/en/news/startup-oxide-launches-on-prem-cloud-computing-rack-system/
[9] Oxide Computer Company https://oxide.computer
[10] Specifications - Oxide Computer https://oxide.computer/product/specifications
[11] Oxide reimagines the DC rack as... a 3000 lb blade server? - Reddit https://www.reddit.com/r/hardware/comments/1au7ckp/oxide_reimagines_the_dc_rack_as_a_3000_lb_blade/

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