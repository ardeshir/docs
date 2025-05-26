# Oxide Innovations

## Oxide Rack: Visual Overview and Technical Innovations

### Visuals of the Oxide Rack and Sleds

While the provided PDF does not contain photographs, several sources—including a recent YouTube tour and technical documentation—offer clear descriptions and some visual cues for the Oxide Rack and its components.

#### Oxide Rack Structure

- The rack is a large, integrated chassis standing 92.7 inches (2354mm) tall, 23.7 inches (600mm) wide, and 41.8 inches (1060mm) deep, weighing up to 2,518 lbs (1,145 kg)[1][2].
- It houses up to 32 custom-designed compute sleds, two integrated network switches, and a centralized power shelf[1][4][6].

#### Compute Sleds

- Each sled is a hot-swappable server module, custom-designed by Oxide (not based on any standard reference design)[6].
- Sleds slide horizontally into the rack, connecting via blind-mate connectors for both power and networking—no manual cabling required for removal or insertion[2][4][6].
- Each sled contains:
  - A single AMD EPYC 7713P processor (64 cores, 128 threads)
  - 16 DDR4 DIMM slots (up to 2 TiB RAM)
  - 10 U.2/U.3 2.5-inch NVMe SSD bays (up to 32 TiB per sled)
  - Dual 100 GbE network connections
  - Custom service processor (no traditional BMC)[1][4][6].

#### Power Shelf

- Located centrally in the rack, the power shelf converts three-phase AC to DC, distributing power via a DC bus bar[1][4][6].
- Supports up to 6 redundant power supplies (N+1 or N+N), delivering up to 15 kW to the rack[1][4].
- All sleds blind-mate to the DC bus bar for power, eliminating the need for individual power cables[2][5][6].

#### Network Switches

- Two custom “Sidecar” switches (one per rack side) use Intel Tofino 2 ASICs, offering 6.4 Tbit/s bandwidth and 32x 100/200G QSFP uplink ports[1][4].
- Rear-facing ports connect directly to sleds via the cabled backplane, while front-facing ports handle external connectivity[1][4].
- Switches also include integrated management ASICs and service processors[4].

#### Cabling and Backplane

- The rack uses a cabled backplane for both networking and power, enabling blind-mate connections for all sleds[4][6].
- This design dramatically reduces cabling clutter, improves airflow, and simplifies maintenance[2][5][6].

#### Visual Representation

While direct photographs are not included in the PDF, the [YouTube tour][6] and CoreSite deployment photos[3] (not included here for copyright reasons) show:

- A tall, clean rack with sleds inserted horizontally from the front.
- Central power shelf and side-mounted switches.
- No visible cabling at the front; all connections are internal/blind-mate.
- Sleds are easily removable for service.

### What Do These Parts Do?

**Compute Sleds:**  
Provide the raw computing power—each is a self-contained server with CPU, memory, storage, and network interfaces. They are designed for easy hot-swap maintenance and high-density deployment[1][4][6].

**Power Shelf:**  
Centralizes power conversion and distribution, improving efficiency and reliability. The DC bus bar approach reduces conversion losses and cabling complexity[2][4][5][6].

**Network Switches:**  
Deliver high-throughput, low-latency networking to every sled, with uplinks for external connectivity and a management network for control and monitoring[1][4].

**Cabled Backplane:**  
Enables blind-mate connections for both power and networking, allowing for tool-less sled replacement and minimizing downtime[2][4][6].

### Technical Innovations

| Feature                        | Oxide Rack Innovation                                                                 | Conventional Rack Approach         |
|---------------------------------|--------------------------------------------------------------------------------------|------------------------------------|
| **Blind-mate Backplane**        | Sleds connect to power and network with no manual cabling.                           | Manual cabling for each server.    |
| **Centralized Power Shelf**     | Single AC→DC conversion, DC bus bar, fewer cables, higher efficiency.                | Individual server PSUs, more cables, less efficient. |
| **Custom Sled Design**          | Designed from scratch for airflow, serviceability, and integration.                  | Based on standard reference designs.|
| **Integrated Switches**         | Custom, high-bandwidth switches with direct sled connections.                        | External switches, more cabling.   |
| **Service Processor**           | Custom, networked service processors replace traditional BMCs for better management. | Standard BMCs, less integration.   |
| **Hot-swappable Everything**    | All sleds, power supplies, and switches are hot-swappable from the front.            | Typically requires rear access and more downtime.    |

#### Additional Innovations

- **Airflow and Cooling:**  
  Larger, more efficient fans reduce power draw for cooling to just 2% of total server power, compared to up to 20% in traditional designs[2][5].

- **Unified Management:**  
  Integrated API, portal, and SDKs allow for seamless provisioning and monitoring of compute, storage, and networking resources[4].

- **Cloud-like On-Premises Experience:**  
  The rack is delivered as a fully integrated system, bringing hyperscale cloud hardware and operational benefits to enterprise data centers[3][5][7].

### Summary



The Oxide Rack is a fully integrated, rack-scale computer system with innovations in power distribution, networking, serviceability, and management. It brings the efficiency and operational model of hyperscale cloud providers to on-premises deployments, offering a unique alternative to traditional piecemeal server racks[2][3][5][6].

For actual photographs and a detailed visual walkthrough, the [YouTube tour][6] is highly recommended, as it provides a close-up look at the rack, sleds, and internal components.

Sources
[1] Oxide-Rack-Specifications-20250217.pdf https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/49592179/fd7a330c-ee66-413b-86fe-343bbf4f1714/Oxide-Rack-Specifications-20250217.pdf
[2] Oxide reimagines the DC rack as... a 2500-lb blade server? https://www.theregister.com/2024/02/16/oxide_3000lb_blade_server/
[3] Oxide deploys racks at CoreSite's SV2 data center in Silicon Valley ... https://www.datacenterdynamics.com/en/news/oxide-deploys-racks-at-coresites-sv2-data-center-in-silicon-valley-california/
[4] Introduction / Guides / Oxide https://docs.oxide.computer/guides/introduction
[5] Row-Scale On-Premises Cloud Infrastructure from Oxide Computer https://futurumgroup.com/insights/row-scale-on-premises-cloud-infrastructure-from-oxide-computer/
[6] Oxide Cloud Computer Tour - Front - YouTube https://www.youtube.com/watch?v=dHbgjB0RQ1s
[7] Startups on hard mode: Oxide. Part 1: Hardware https://newsletter.pragmaticengineer.com/p/oxide
[8] Oxide Computer Company https://oxide.computer
[9] Specifications - Oxide Computer https://oxide.computer/product/specifications
[10] A New Standard in National Security and Innovation - Oxide Computer https://oxide.computer/blog/oxide-computer-company-and-lawrence-livermore-national-laboratory
[11] Initial Rack Setup / Guides / Oxide https://docs.oxide.computer/guides/system/initial-rack-setup
