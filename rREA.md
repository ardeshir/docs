# What is hREA?

hREA (Holochain Resource-Event-Agent ) is an implementation of the Valueflows specification that enables a transparent and trusted account of resource and information flows between decentralized and independent agents, across and within ecosystems.

It’s built on three core concepts from REA accounting theory:

**Resources** - Economic resources would typically be useful goods and services, but could also be money, credits, energy, knowledge, designs, skills, CO2, methane, air, water, or almost anything else that some Agents can agree should be accounted for in their economic networks. 

**Events** - Economic Events affecting Economic Resources. An Economic Event can take actions like produce, modify, consume, or use Economic Resources, or transfer them from one Agent to another, or transport them from one location to another. 

**Agents** - Agents are individual persons or organizations or ecological agents, who perform Economic Events affecting Economic Resources. 

## How it Identifies Community Needs

hREA doesn’t automatically “identify” needs in the traditional AI sense. Instead, it creates a framework where community needs emerge through:

1. **Transparent Resource Tracking**: hREA, and ValueFlows, are fundamentally a system for capturing structured information, particularly about real world economic events (think transfers, production, etc.) and relationships. It is about allowing a community, business, or network to see all the ways in which it is connected to itself and the larger world. 
1. **Value Flow Mapping**: Value means useful economic resources. Flows means how people create, combine, move, and exchange them. Networks of value flows are created when processes and transfers are linked together through flows of resources. 
1. **Multi-perspective Accounting**: Instead of only the basic kind of financial accounting we’re used to, from hREA data you can produce those reports from the viewpoint of any agent in the network, do tracking and tracing through a supply chain, and more. 

## How it Distributes Resources

hREA handles distribution through several mechanisms:

1. **Process-Based Flows**: Input-Process-Output resource chains, where one Economic Resource is the output of one Process and then becomes an input to another, thus connecting the processes into a flow. 
1. **Agent-to-Agent Transfers**: Some flows do not involve processing, i.e. there is no transformation or transportation of Economic Resources. These flows simply transfer Economic Resources between Agents. 
1. **Coordination Networks**: The Agents involved in each Process in the chain need to coordinate with the previous and next Processes about the quantity, quality, and timing of resource flows between them. 

## Real-World Applications

hREA is being used in various contexts like mutual aid networks, open value networks, DAOs , and projects like LearnDeep, initially created by students at MSOE, supports a network of high school fablabs in Milwaukee that receive contributions of materials from the community and share these with each other. 

The key insight is that hREA doesn’t centrally decide what communities need or how to distribute resources. Instead, it provides a transparent, decentralized infrastructure where communities can track their own resources, coordinate their economic activities, and make informed decisions based on complete visibility into their resource flows and relationships.

Let me break down the specific technical mechanisms that hREA uses to keep communities informed about their resources in a more focused way:​​​​​​​​​​​​​​​​

## How hREA’s Protocol Works to Keep Communities Informed

Here are the core mechanisms that make resource visibility work in hREA:

### **1. Distributed Real-Time Ledger**

Having the ‘realtime’ (signaling) affordances of Holochain, but also the offline-friendly affordances of eventual consistency, are both crucial to forming resilient economic networks. The always-on availability of data during network growth thanks to the self-healing / dynamic DHT is another important affordance. 

**How it works:** Every resource movement is recorded as an “Economic Event” that gets distributed across all community nodes instantly. When someone uses shared tools, contributes materials, or creates outputs, everyone sees it immediately.

### **2. Event-Based Resource Tracking**

By transparently tracking Resources and Events, hREA empowers Agents; worker, small businesses, etc to verify  what’s happening in their community.

**How it works:** Every resource interaction creates a permanent record:

- **Use**: “Maria borrowed the 3D printer”
- **Contribute**: “Tom donated 5 lbs of tomatoes”
- **Create**: “The workshop produced 20 planters”
- **Transfer**: “Moved tools from storage to makerspace”

### **3. GraphQL Query System**

You’ll find all the documentation you need to get up and running with the hREA APIs. While this documentation discusses a set of GraphQL APIs 

**How it works:** Community members can ask specific questions:

```
- "What tools are available right now?"
- "Who contributed materials this week?"
- "How many tomatoes do we have in storage?"
- "What projects are using our shared resources?"
```

### **4. Multi-Agent Perspective Views**

from hREA data you can produce those reports from the viewpoint of any agent in the network, do tracking and tracing through a supply chain, and more. 

**How it works:** Each community member sees resource data from their perspective:

- **Individual view**: “Resources I’ve contributed/borrowed”
- **Group view**: “Our collective inventory”
- **Process view**: “Resources flowing through our projects”

### **5. Resource Lifecycle Visibility**

hREA, by contrast, emphasises resource lifecycle tracking in its entirety. Each Resource, whether a raw material, product, or byproduct, can be traced through its creation, use, reuse, and eventual recycling or composting - each Event in the product’s lifecycle can be mapped. 

**How it works:** Communities can trace any resource’s complete journey:

- Where it came from (provenance)
- Who’s used it and when
- What it was transformed into
- Where it is now

### **6. Customizable Community Interfaces**

Build the tailor-made user interfaces that your scenario needs with our extensively documented APIs and frontend libraries. 

**How it works:** Communities can build dashboards showing exactly what they need:

- Garden cooperatives track produce and growing supplies
- Makerspaces monitor tools and materials
- Mutual aid networks track needs and contributions

### **7. Interconnected Network Visibility**

Now, Agents in the network will be able to offer their output, based on their individual or collaborative efforts, ensuring their needs are met by making them visible. 

**How it works:** Communities can see beyond their boundaries:

- Available resources in connected communities
- Opportunities to share or trade
- Collaborative projects across networks

### **Key Difference from Traditional Systems**

Unlike centralized databases where data flows upward to administrators, hREA creates **horizontal transparency**. It is about allowing a community, business, or network to see all the ways in which it is connected to itself and the larger world. 

Every community member has equal access to the same resource information, creating shared situational awareness that enables collective decision-making and resource coordination without central control.

The protocol doesn’t tell communities what to do—it makes all resource flows visible so communities can make informed decisions together.
