# SAVE DIRECT FILE: The Flagship Spirit

**Preserving Public Good on the Digital Commons**

-----

## The Story

On January 2026, IRS Commissioner Billy Long announced with glee: **“You’ve heard of Direct File, that’s gone. Big beautiful Billy wiped that out.”**

Direct File was a free, government-built tax filing system that:

- Saved taxpayers $5.6 million in tax preparation costs
- Let Americans file taxes directly with the IRS at no charge
- Was praised for being simple, accessible, and effective
- Worked in 25 states by 2025

It was killed by:

- Corporate lobbying from Intuit (TurboTax) and H&R Block
- DOGE’s destruction of 18F (the team that built it)
- Republican lawmakers funded by tax prep companies
- An administration that decided “the private sector can do a better job”

**But they made one mistake: they open-sourced the code first.**

Direct File is public domain software. It belongs to the American people. And the Digital Commons will preserve it.

-----

## Why Direct File as First Spirit

### 1. Maximum Symbolic Power

This isn’t abstract infrastructure. This is:

- **“The government killed your free tax tool”**
- **“Corporations paid to take it away”**
- **“But we saved it”**

Every American understands taxes. Every American hates paying $140 to file them. This is visceral.

### 2. Technical Demonstration

Direct File proves the VUDO platform can host:

- Complex, real-world applications
- Interview-based user interfaces
- State API integrations
- Genuine mission-critical software

### 3. Political Bridge

Direct File was built by USDS—the same people now leading Tech Viaduct:

- Mikey Dickerson founded USDS
- Marina Nitze worked at VA (similar modernization work)
- The Tech Viaduct team built this kind of software

Preserving their work on the commons creates natural alliance.

### 4. Network Effect Catalyst

If people can file taxes on the commons:

- They create identities (Ed25519)
- They experience sovereignty
- They become users, then advocates, then Nexus Rebels

Tax filing is the gateway drug.

-----

## Technical Assessment

### What’s in the Repository

```
github.com/ardeshir/direct-file (fork of IRS-Public/direct-file)
├── direct-file/          Main application
├── docs/                  Documentation
├── LICENSE               Public domain
├── ONBOARDING.md         Local setup instructions
└── README.md             Overview
```

**Stack:**

- JavaScript (45%)
- TypeScript (32%)
- Java (14%)
- Scala (7%)
- HTML/SCSS

**Key Components:**

1. **Fact Graph** — Declarative, XML-based knowledge graph for reasoning about incomplete information (partially completed tax returns)
1. **Interview Engine** — Transforms tax code into plain-language questions
1. **MeF Integration** — Connects to IRS Modernized e-File API
1. **State API** — Transfers data to state filing systems

### Adaptation Requirements

|Component      |Current State     |VUDO Adaptation                     |
|---------------|------------------|------------------------------------|
|Frontend       |React-based       |Port to VUDO web stack              |
|Fact Graph     |Scala/Scala.js    |Keep as-is (runs in JVM/browser)    |
|Backend        |Java              |Containerize for VUDO nodes         |
|MeF Integration|Direct API calls  |Proxy through commons infrastructure|
|Identity       |IRS Online Account|Ed25519 + optional IRS link         |
|State API      |JSON/XML transfer |Preserve as-is                      |

### Critical Dependencies

1. **MeF API Access** — The IRS Modernized e-File API is still available for authorized use. Need to register as e-file provider.
1. **Tax Year Updates** — Tax code changes annually. Need ongoing maintenance.
1. **State Partnerships** — States that participated in Direct File may still accept transfers.

-----

## Deployment Strategy

### Phase A: Archive & Document (Immediate)

**Objective:** Ensure the code is preserved and understood

Tasks:

- [ ] Fork IRS-Public/direct-file to univrs organization
- [ ] Document all dependencies and build requirements
- [ ] Create reproducible build process
- [ ] Archive all associated documentation
- [ ] Map Fact Graph structure and business rules

**Timeline:** 1 week
**Output:** Complete preservation with build documentation

### Phase B: Local Development (Weeks 2-4)

**Objective:** Get Direct File running locally on VUDO infrastructure

Tasks:

- [ ] Set up local development environment
- [ ] Identify and resolve dependency issues
- [ ] Create Docker/container configuration
- [ ] Test interview flow end-to-end
- [ ] Document differences from IRS deployment

**Timeline:** 3 weeks
**Output:** Working local instance

### Phase C: Commons Integration (Weeks 5-8)

**Objective:** Integrate with VUDO platform primitives

Tasks:

- [ ] Replace authentication with Ed25519 identity
- [ ] Integrate with ENR credit system (free tier, optional donations)
- [ ] Connect to VUDO node infrastructure
- [ ] Create Spirit manifest and packaging
- [ ] Test multi-node deployment

**Timeline:** 4 weeks
**Output:** Direct File as VUDO Spirit

### Phase D: MeF Authorization (Parallel Track)

**Objective:** Obtain legal authorization to transmit returns

Tasks:

- [ ] Research e-file provider requirements
- [ ] Assess organizational structure needs (may need nonprofit entity)
- [ ] Apply for EFIN (Electronic Filing Identification Number)
- [ ] Complete IRS acceptance testing
- [ ] Establish compliance procedures

**Timeline:** 3-6 months (regulatory process)
**Output:** Authorized e-file provider status

### Phase E: Public Launch (Q3 2026)

**Objective:** Offer Direct File to American taxpayers

Tasks:

- [ ] Marketing campaign: “Save Direct File”
- [ ] User testing with beta community
- [ ] State partnership outreach
- [ ] Media and press strategy
- [ ] Support infrastructure

**Timeline:** Target Tax Year 2025 returns (filed in 2026)
**Output:** Live service on Digital Commons

-----

## Legal Considerations

### Code Licensing

Direct File is public domain as a work of the U.S. government. Per the LICENSE file and federal law:

> “As a work of the United States Government, this project is in the public domain within the United States.”

**We can legally:**

- Fork and modify the code
- Host and distribute it
- Offer it as a service

### MeF API Access

The Modernized e-File API is available for authorized public use. Requirements:

- Register as e-file provider
- Obtain EFIN
- Pass acceptance testing
- Maintain compliance

**This is not exclusive to commercial providers.** The API was designed for public access.

### Organizational Structure

To operate as e-file provider, may need:

- Nonprofit entity (501(c)(3) or similar)
- Clear governance structure
- Compliance officer
- Data protection procedures

**Recommendation:** Establish “Digital Commons Foundation” or similar entity.

### Tax Data Privacy

Direct File handles sensitive financial information. Requirements:

- FTI (Federal Tax Information) protections
- PII safeguards
- IRS Publication 1075 compliance
- State-specific requirements

**Advantage:** P2P architecture means data doesn’t concentrate. User controls their own information.

-----

## Campaign Strategy: “Save Direct File”

### Messaging

**Primary:** “They killed your free tax tool. We saved it.”

**Supporting:**

- “Corporations paid $X million to take away your right to file for free”
- “The code belongs to the American people. We’re giving it back.”
- “File your taxes on infrastructure you own”
- “No corporation takes 30%. No government can shut it down.”

### Audience Segments

|Segment                        |Message                                           |Channel                     |
|-------------------------------|--------------------------------------------------|----------------------------|
|Tax filers who used Direct File|“It’s back, and now it’s yours”                   |Email, targeted ads         |
|Tax policy advocates           |“Join the fight for free filing”                  |Policy networks, newsletters|
|Tech community                 |“Help preserve public domain software”            |GitHub, Hacker News, Reddit |
|Civic tech organizations       |“Code for America, meet Code for Commons”         |Direct outreach             |
|Media                          |“David vs. Goliath: Citizens reclaim tax software”|Press releases, interviews  |

### Key Moments

1. **Code Preservation Announcement** — “Univrs.io archives Direct File for the commons”
1. **Development Milestone** — “Direct File now runs on decentralized infrastructure”
1. **MeF Authorization** — “Digital Commons approved as e-file provider”
1. **Public Launch** — “File your 2025 taxes for free on the Digital Commons”

### Coalition Building

Potential allies:

- Economic Security Project (led Direct File advocacy)
- Code for America (Amanda Renteria already spoke out)
- Electronic Frontier Foundation
- Public Knowledge
- State tax administrators who lost the partnership
- Former USDS/18F team members

-----

## Resource Requirements

### Technical

|Role                          |Effort     |Source           |
|------------------------------|-----------|-----------------|
|Full-stack developer (Java/TS)|20 hrs/week|Contributor/hire |
|Scala developer (Fact Graph)  |10 hrs/week|Contributor      |
|DevOps (containerization)     |10 hrs/week|Existing capacity|
|Tax domain expert             |5 hrs/week |Advisor/volunteer|

### Legal/Compliance

|Item               |Estimated Cost|Source          |
|-------------------|--------------|----------------|
|Nonprofit formation|$2,000-5,000  |Legal services  |
|EFIN application   |Staff time    |Internal        |
|Compliance review  |$5,000-10,000 |Consultant      |
|Ongoing maintenance|$2,000/year   |Operating budget|

### Campaign

|Item                  |Estimated Cost     |Source          |
|----------------------|-------------------|----------------|
|Website/landing page  |$0 (existing infra)|Internal        |
|Press outreach        |Staff time         |Internal        |
|Social media          |$500/month         |Operating budget|
|Advertising (optional)|$2,000-10,000      |Grants/donations|

### Total Year 1 Budget: $20,000-50,000

Fundable through:

- Foundation grants (Mozilla, Ford, etc.)
- Crowdfunding (“Save Direct File” campaign)
- SAINT token contributor incentives
- In-kind donations (hosting, development time)

-----

## Success Metrics

### Technical

- [ ] Direct File builds from source
- [ ] All interview flows functional
- [ ] MeF test submissions succeed
- [ ] 1,000+ test returns processed

### Adoption

- [ ] 10,000 returns filed in first season
- [ ] 100,000 returns filed in second season
- [ ] 5+ states re-engage for state transfers

### Movement

- [ ] 10 media mentions
- [ ] 1,000 GitHub stars
- [ ] 100 contributors
- [ ] 50 Nexus nodes running Direct File

### Political

- [ ] Congressional awareness of commons alternative
- [ ] Tech Viaduct acknowledges preservation effort
- [ ] State legislators introduce “digital commons” bills

-----

## Risk Assessment

|Risk                          |Likelihood|Impact  |Mitigation                             |
|------------------------------|----------|--------|---------------------------------------|
|MeF authorization denied      |Low       |Critical|Early engagement with IRS, legal review|
|Tax code changes break system |High      |Medium  |Ongoing maintenance commitment         |
|Insufficient contributors     |Medium    |High    |Funded positions, grant support        |
|Corporate/political opposition|Medium    |Medium  |Coalition building, legal preparation  |
|User trust concerns           |Medium    |Medium  |Transparency, security audits          |

-----

## The Larger Vision

Direct File is not the end goal. It’s the proof point.

If the Digital Commons can preserve and operate a complex, mission-critical government service that corporations and captured politicians tried to kill:

- **What else can we preserve?**
- **What else can we build?**
- **What else belongs to the people?**

Direct File on the commons demonstrates:

1. Decentralized infrastructure works for real applications
1. Public domain software can be kept alive by the public
1. Citizens can operate services government won’t
1. The commons is not abstract—it files your taxes

**This is how you build a movement: one victory at a time.**

-----

## Immediate Actions

### This Week

1. [ ] Fork IRS-Public/direct-file to univrs organization
1. [ ] Review ONBOARDING.md and attempt local build
1. [ ] Document all dependencies and blockers
1. [ ] Research EFIN application requirements
1. [ ] Draft “Save Direct File” announcement

### This Month

1. [ ] Establish reproducible build process
1. [ ] Create containerized deployment
1. [ ] Begin nonprofit formation research
1. [ ] Reach out to Economic Security Project
1. [ ] Connect with former Direct File team members

### This Quarter

1. [ ] Direct File running on VUDO infrastructure
1. [ ] Legal structure for e-file provider status
1. [ ] Coalition partners engaged
1. [ ] Public announcement and campaign launch

-----

*“You’ve heard of Direct File, that’s gone.”*
*— IRS Commissioner Billy Long, January 2026*

*“No. It’s ours now.”*
*— The Nexus Rebels*

🍄✊📊