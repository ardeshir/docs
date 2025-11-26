## Oxide Rack Management Plane OS and Integration

**Operating System Choice**

Oxide's rack management plane runs its control plane services directly on the same servers that provide compute and storage for customer workloads. The host operating system and hypervisor stack are custom-built by Oxide, with a strong emphasis on hardware/software co-design. While Oxide has considered options like Linux and illumos for development and testing, their production stack is a purpose-built OS and hypervisor designed specifically for their hardware[3][9]. This OS is not a generic distribution but is tightly integrated with their hardware and control plane software.

**Integration with Unified Hardware & Software Philosophy**

- The control plane (including components like Nexus, sled-agent, and management-gateway-service) runs as distributed clusters across the rack, directly on the compute sleds[1][5].
- This architecture eliminates the need for external management controllers or legacy solutions like VMware or OpenStack, creating a unified, cloud-like experience on-premises[5].
- The OS enables seamless orchestration of virtual machines, storage, and networking, with live migration and full-rack fault management—workloads are proactively moved before hardware issues impact service[4].

**Manifestation of System Design Philosophy**

- Oxide’s OS is built for horizontal scalability, high availability, and deep integration with telemetry, metrics, and automation APIs[1][4].
- The software stack is designed to manage not just VMs, but the entire rack’s lifecycle—including hardware inventory, fault detection, and software updates—reflecting a system built for true cloud operations in private data centers[1][5].
- The use of a custom OS and hypervisor, rather than adapting an off-the-shelf solution, underscores Oxide’s focus on reliability, observability, and tight coupling between hardware and software. This enables features like rack-level trust establishment, unified identity, and seamless management of both compute and networking resources[1][3].

**Summary Table**

| Aspect | Oxide Rack Approach |
|-------------------------|-----------------------------------------------------|
| Management OS | Custom, rack-specific OS & hypervisor |
| Integration | Runs directly on compute sleds (no external BMCs) |
| Philosophy Manifested | Unified, cloud-native, hardware/software co-design |
| System Managed | Full rack: compute, storage, networking, telemetry |

Oxide’s choice of a custom, tightly integrated OS for rack management enables a seamless, cloud-like experience with unified hardware and software, high automation, and robust fault management—tailored for modern, private cloud deployments[1][3][5].

## What This Means

Oxide Computer Company has built a **custom operating system and hypervisor** that runs directly on their rack servers, instead of using existing solutions like Linux, VMware, or OpenStack. Their control plane software (the brain that manages everything) runs on the same physical servers that handle customer workloads, rather than requiring separate management hardware.

Think of it like this: instead of buying a pre-built car and trying to modify it, Oxide built their own car from scratch, designing every component to work perfectly together.

## Why This Is Innovative

**1. Eliminates Infrastructure Complexity**
- Traditional data centers require separate management controllers, external orchestration software, and complex integration between different vendors' products
- Oxide's approach means everything is unified - one OS manages compute, storage, networking, and monitoring all together

**2. True Hardware-Software Integration**
- Most companies either make hardware OR software, then try to make them work together
- Oxide designed both simultaneously, allowing for optimizations impossible when using off-the-shelf components
- This enables features like automatic hardware fault detection and workload migration before failures occur

**3. Cloud Experience On-Premises**
- Brings the seamless experience of AWS/Azure to private data centers
- Everything "just works" without the typical complexity of enterprise infrastructure
- Automatic scaling, live migration, and self-healing capabilities built in from the ground up

**4. Operational Simplicity**
- Single vendor, single support contract, single software stack
- Updates and management happen across the entire rack as one coordinated system
- Eliminates the typical "vendor finger-pointing" when things go wrong

This represents a fundamental shift from the traditional approach of assembling data center infrastructure from multiple vendors' components, instead delivering a unified, purpose-built cloud platform.​​​​​​​​​​​​​​​​



Sources: 
1. [Control Plane / Guides / Oxide ](https://docs.oxide.computer/guides/architecture/control-plane)
2. [Oxide Computer Company ](https://oxide.computer)
3. [Host Operating System & Hypervisor / RFD 26 - Oxide Computer ](https://26.rfd.oxide.computer)
4. [On-Demand Virtual Machines - Oxide Computer ](https://oxide.computer/product/compute)
5. [How Oxide Created a Cloud Server by Stripping Components, Wires](https://www.hpcwire.com/2023/11/01/how-oxide-created-a-cloud-server-by-stripping-components-wires-cables-and-chips/)
6. [PDF - Understanding Operating Systems - Yonkers Public Schools ](https://www.yonkerspublicschools.org/cms/lib/NY01814060/Centricity/Domain/912/Operating%20Systems.pdf)
7. [RFD 53 Control plane data storage requirements - Oxide RFD](https://rfd.shared.oxide.computer/rfd/53)
8. [CEIS101-C Module 4 Flashcards - Quizlet ](https://quizlet.com/746628495/ceis101-c-module-4-flash-cards/)
9. [Omicron: Oxide control plane - GitHub ](https://github.com/oxidecomputer/omicron)
