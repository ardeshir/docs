# SunOS, Solaris and Illumos

Tracing their lineage from BSD and System V Unix roots, evolving through strategic shifts in codebase and branding. Here's a structured overview:

## BSD-Based SunOS Era (1982–1994)
- **Origins**: SunOS 1.0 (1983) emerged from 4.1BSD, powering Sun's early 68000/68010 workstations[1][3]. Key milestones:
- **NFS and RPC**: Introduced in SunOS 2.0 (1985), revolutionizing networked computing[1][3].
- **Hybridization**: SunOS 3.0 (1986) incorporated System V IPC alongside BSD, reflecting Unix fragmentation[1][3].
- **Final BSD Iteration**: SunOS 4.1.4 (1994) marked the last BSD-derived release, supporting SPARC sun4/sun4c/sun4m architectures[1][3].

## Transition to System V (1991–1993)
- **SVR4 Foundation**: Collaboration with AT&T (1987) led to System V Release 4 adoption[1][4]. SunOS 5.0 (1992) became the core of **Solaris 2.0**, rebranding BSD-based SunOS 4.x as *Solaris 1.x*[1][2].
- **Key Changes**:
- **Kernel Architecture**: Shift from BSD to SVR4 process/tty/streams models.
- **ABI Compatibility**: Introduced binary compatibility layers for legacy SunOS 4 apps[1].

## Solaris Evolution (1993–2010)
- **Feature Innovations**:
- **Solaris 2.4** (1994): Unified SPARC/x86 codebase[2].
- **Solaris 7** (1998): 64-bit support and dropped "2." from versioning[2].
- **Solaris 10** (2005): Introduced ZFS, DTrace, and Service Management Facility (SMF)[2].
- **Open-Source Phase**:
- **OpenSolaris** (2005–2010): Sun open-sourced Solaris code, creating a community-driven project with Illumos kernel components[^knowledge].

## Fork and Legacy (2010–Present)
- **Oracle Acquisition** (2010): Discontinued OpenSolaris, leading to:
- **Illumos**: Community fork maintaining open-source kernel components, spawning distributions like OmniOS and SmartOS[^knowledge].
- **Oracle Solaris 11** (2011): Proprietary continuation with focus on cloud/enterprise features, latest release 11.4 (2018)[2].

### Major Divergences
| Aspect | Solaris (Oracle) | Illumos Derivatives |
|-----------------|---------------------------|---------------------------|
| **Licensing** | Proprietary | Open-Source (CDDL) |
| **Focus** | Enterprise/SPARC | Cloud/Linux compatibility |
| **Features** | Oracle-specific security | Community-driven updates |
| **Platforms** | SPARC/x86 | x86/KVM virtualization |

## Historical Turning Points
- **1991**: SunOS 5/Solaris 2 announcement, marking SVR4 transition[1][4].
- **2005**: OpenSolaris launch, enabling ZFS/DTrace community contributions[^knowledge].
- **2010**: Oracle's OpenSolaris discontinuation and Illumos fork[^knowledge].
- **2017**: Oracle layoffs in Solaris team, reducing development pace[2].

This lineage shows a progression from BSD roots to enterprise System V implementation, followed by open-source experimentation and eventual fragmentation into proprietary/community branches.

Sources
[1] SunOS - Wikipedia https://en.wikipedia.org/wiki/SunOS
[2] Oracle Solaris - Wikipedia https://en.wikipedia.org/wiki/Oracle_Solaris
[3] SunOS - Computer History Wiki - gunkies.org https://gunkies.org/wiki/SunOS
[4] A Brief History of Solaris http://solaris4livin.blogspot.com/2009/11/brief-history-of-solaris.html
[5] [PDF] Milestones in the Development of Solaris - filibeto.org https://www.filibeto.org/aduritz/truetrue/solaris10/history_of_solaris.pdf
[6] Is OpenSolaris or Illumos anyhow relevant to linux users - Reddit https://www.reddit.com/r/linuxquestions/comments/kjvdp5/is_opensolaris_or_illumos_anyhow_relevant_to/
[7] OpenSolaris - Wikipedia https://en.wikipedia.org/wiki/OpenSolaris
[8] Whither OpenSolaris? Illumos Takes Up the Mantle - LinuxInsider https://www.linuxinsider.com/story/whither-opensolaris-illumos-takes-up-the-mantle-76669.html
[9] Comparison of OpenSolaris distributions - Wikipedia https://en.wikipedia.org/wiki/Comparison_of_OpenSolaris_distributions
[10] OpenSolaris - DistrOSList - V A R G U X https://distroslist.vargux.org/index.php/OpenSolaris
[11] FreeBSD vs. Illumos https://forums.freebsd.org/threads/freebsd-vs-illumos.92010/
[12] the Illumos eco system - zero-knowledge https://zero-knowledge.org/post/83.html
[13] Cleaning Up illumos and Solaris OS Support · Issue #2181 - GitHub https://github.com/svaarala/duktape/issues/2181
[14] UNIX System V - Wikipedia https://en.wikipedia.org/wiki/UNIX_System_V
[15] The UNIX System -- History and Timeline - UNIX.org https://unix.org/what_is_unix/history_timeline.html
[16] UNIX System V - Computer History Wiki - gunkies.org https://gunkies.org/wiki/UNIX_System_V
[17] The History Of The Solaris Operating System - SourceTech Systems https://source-tech.net/the-history-of-the-solaris-operating-system/
[18] Unix Family Tree : r/linux - Reddit https://www.reddit.com/r/linux/comments/huhqrh/unix_family_tree/
[19] What is the difference between BSD, Linux, and Solaris? - Reddit https://www.reddit.com/r/linux4noobs/comments/32hda0/what_is_the_difference_between_bsd_linux_and/
[20] [PDF] The History of Solaris https://cse.unl.edu/~witty/class/csce351/howto/history_of_solaris.pdf
[21] Community History - SmartOS Documentation https://docs.smartos.org/community-history/
[22] SunOS & Solaris Version History https://web-docs.gsi.de/~kraemer/COLLECTION/SOLARIS/SunOSandSolarisVersionHistory.html
[23] A brief history with Solaris - The Trouble with Tribbles... https://ptribble.blogspot.com/2019/10/a-brief-history-with-solaris.html
[24] Solaris Operating System - Releases - Oracle https://www.oracle.com/solaris/technologies/releases.html
[25] Illumos - Wikipedia https://en.wikipedia.org/wiki/Illumos


https://www.perplexity.ai/search/2e232c4f-1d30-4230-9354-7895c5df9949