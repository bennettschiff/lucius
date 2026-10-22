# Techtool Pro features in Lucius

## October 22 review and implementation update

The 0.2 build was a useful inventory/status overview, not an equivalent to Techtool's active hardware tests. Version 0.3 adds four substantive hardware capabilities alongside it:

| Area | Implemented in Lucius 0.3 | Remaining limit |
| --- | --- | --- |
| CPU | Bounded concurrent integer and floating-point known-answer workload | Not every instruction, cache, physical core or sustained burn-in |
| RAM | Six patterns over 64 MiB; 384 MiB compared, corruption count/offset | Process virtual allocation only; cannot certify all physical RAM |
| GPU | Four Metal compute passes; all 4,194,304 outputs independently compared | One selected device, 8 MiB of buffers; no all-VRAM/display test |
| Cooling | 10-second raw temperature/RPM/thermal trace, chart and samples | Read-only, undocumented SMC compatibility; no calibrated sensor fault diagnosis or fan control |
| Reporting | Last ten detailed hardware reports, partial/not-run outcomes, export and coverage | Overview reports still use the earlier export plus compact-history model |

Techtool's fan test actively varies fan speed. Lucius does not claim this. The development machine reports `Mac15,13`, which Apple identifies as a 15-inch M3 MacBook Air; Apple's product description confirms the fanless design. There is no fan to exercise on this machine. On fan-equipped Macs, readable RPM is only an observation; implementing control needs validated, model-specific SMC write behavior and recovery to automatic control. No such writes are present.

Sources: [Techtool Pro manual](https://www.micromat.com/product_manuals/techtool_pro_21_manual.pdf), [Apple model identification](https://support.apple.com/en-ie/102869), [Apple M3 Air description](https://www.apple.com/newsroom/2024/03/apple-unveils-the-new-13-and-15-inch-macbook-air-with-the-powerful-m3-chip/), [Metal compute](https://developer.apple.com/documentation/metal/performing-calculations-on-a-gpu), and the [MIT-licensed Stats SMC adapter](https://github.com/exelban/stats/blob/master/SMC/smc.swift). The SMC wire layout/read encodings were cross-checked with Stats; attribution is included in `THIRD-PARTY-NOTICES.md` and the app bundle.

Still outside this release: detailed SMART, physical USB/Bluetooth/Thunderbolt tests, active network/DNS probes, Bonjour discovery, complete media decoding, disk benchmarks and background monitoring. Disk repair/recovery/cloning/wiping remain outside the accepted scope. The original feasibility classification below is historical planning, not a statement that those candidates all shipped.


Assessment: October 18, 2026. Original feasibility study with an implementation update below.

## Accepted scope and implementation update

The user approved expanding everyday diagnostics and excluded the disk-repair side of the product. Disk repair, recovery, cloning, initialization and wiping are outside the current roadmap. Keep the existing narrowly targeted Notification Center recovery flow.

Lucius 0.2 now implements the first diagnostic release: configurable system groups; memory-pressure/swap and thermal observations; local capacity; battery/UPS information; interface enumeration; three security-configuration checks; hardware inventory; selected-app signature/architecture inspection; selected small-file validation; and Markdown report export. Run summaries are stored locally. See README.md and HANDOFF.md for exact limits and verification.

The matrix below remains a feasibility inventory, not a statement that every proposed capability is implemented. Detailed SMART/sensor adapters, active connectivity probes, Bonjour, background monitoring/email, benchmarks and hardware workload tests remain future work. They require their own compatibility and lifecycle validation.

**We could build useful equivalents for 26 of 30 grouped capabilities: 14 direct candidates and 12 with narrower coverage or significant engineering. Four are poor priorities for Lucius.** This is my engineering assessment, not a measured feature-parity percentage or Micromat's official feature count. Groups consolidate overlapping tests, tools, and monitoring functions; they are not equal in effort or value.

The comparison uses [Micromat's current product page](https://www.micromat.com/products/techtool-pro/) and [Techtool Pro 21 manual](https://www.micromat.com/product_manuals/techtool_pro_21_manual.pdf). The manual adds capabilities beyond the marketing page. Its legacy passages should not be treated as proof of support on every current Mac.

## What Lucius has today

Verified by reading README.md, HANDOFF.md, Package.swift, Component.swift, Scanner.swift, and ScanStore.swift in this checkout:

- Native SwiftUI/SwiftPM, macOS 14 deployment target, no third-party dependencies.
- Bounded resource observations for six interface processes, with symptom prioritization and conservative findings.
- Identity-checked Notification Center restart and separate verification of process replacement and user-reported recovery.
- Bounded local incident history, cancellation, and an existing visual scan interface.
- No implemented hardware diagnostics, disk tests, networking checks, background monitor, or privileged helper.

Existing scanning and history are reusable foundations, not completed equivalents of Techtool's test suites or reports. This assessment did not rerun the app or validate any proposed hardware adapter. The handoff records testing on one Apple silicon Mac; broader OS/model coverage remains unverified.

## 14 direct implementation candidates

“Direct” means a credible route using ordinary application APIs or existing macOS utilities. It does not mean already implemented, trivial, or equally valuable. Access to protected files, notifications, or the local network may still require user permission.

| # | Capability | Proposed Lucius implementation and boundary |
| --- | --- | --- |
| 1 | Configurable test suites | Quick, storage, connectivity, and custom selections; explicit time budgets and skipped checks. Generalize the existing scan orchestration. |
| 2 | Reports and history | Typed findings, evidence timestamps, before/after comparisons, and user-triggered export. Extend incident storage with retention limits. |
| 3 | Battery information | Read OS-reported condition, capacity and cycle information where available; show source and missing fields. Do not predict an exact replacement date. |
| 4 | UPS information | Use power-source APIs for supported UPS devices. Show unavailable fields honestly; validate on real UPS hardware. |
| 5 | Storage usage | Show volumes, free space and shared APFS container context. Distinguish available/purgeable space; do not add overlapping capacities together. |
| 6 | File validation | Start with plist/XML and image decoding, then PDF/media support. Check selected folders with file/byte/time limits; unreadable or unsupported does not mean corrupt. |
| 7 | Disk speed | Bounded temporary-file workload on a selected writable volume, space check and cleanup. Report workload/cache assumptions; do not run on a possibly failing drive. |
| 8 | App inspection | Bundle metadata, architecture, signature assessment and compatibility clues. A valid signature does not establish that an app is harmless. |
| 9 | Security configuration | Read-only checks of observable protections, with explanations and Settings links. An unavailable check is unknown; this is not an antivirus engine. |
| 10 | Network interface checks | Interface/path state plus explicit DNS and connection probes. Identify whether the failure is local, name resolution, or a selected endpoint; avoid declaring the entire internet healthy. |
| 11 | Local service discovery | Bounded Bonjour browsing for chosen service types, useful for missing printers or shared services. It cannot enumerate every device or open port. |
| 12 | Optional monitoring | User-enabled helper, event-driven updates where available, infrequent checks, sleep/wake handling and alert cooldowns. This expands the current on-demand product scope. |
| 13 | Email notifications | Optional configured delivery with Keychain credentials, redacted content and bounded retries. Feasible but lower priority than local alerts; no bundled mail-service assumption. |
| 14 | Disk image creation | Wrap supported image creation for selected folders/data volumes, with destination capacity checks and result verification. Do not equate this with a bootable system backup. |

Apple documents [power-source state](https://developer.apple.com/documentation/iokit/kiopspowersourcestatekey), [Bonjour browsing and local-network declarations](https://developer.apple.com/documentation/Network/NWBrowser), and [helper lifecycle/approval](https://developer.apple.com/documentation/servicemanagement/smappservice/register()). These support the proposed routes; additional battery-health fields and device coverage need implementation probes.

## 12 feasible with substantial limits

| # | Capability | Useful scope and main limitation |
| --- | --- | --- |
| 15 | USB, Thunderbolt and Bluetooth checks | Inventory, connection state, reconnect evidence and supported functional probes. Device discovery is not a physical bus or radio integrity test; permissions and device-specific protocols vary. |
| 16 | CPU/cache testing and processor telemetry | Finite arithmetic/checksum workloads plus available utilization, thermal and power measurements. Cannot isolate every CPU/cache fault or guarantee per-core power/frequency across models. Detailed telemetry may require elevation. |
| 17 | RAM testing | Pattern tests in a capped allocation, stopping on memory pressure. Only tests memory made available to the process; cannot cover all physical RAM or replace offline diagnostics. Avoid aggressive memory reclamation. |
| 18 | GPU/video-memory testing | Bounded Metal compute/render verification over allocated resources. Coverage depends on GPU and unified versus dedicated memory; cannot certify the whole GPU or all memory. |
| 19 | Fans and sensors | Start with OS thermal state; investigate supported temperature/RPM sources separately. Full sensor coverage, valid thresholds and active fan testing require model-specific research. Do not ship fan control as a universal capability. |
| 20 | SMART/NVMe drive health | Basic status first, then supported health counters through a reviewed adapter or dependency. Device/bridge support varies; a passing status is not assurance against failure. No universal USB-drive coverage promise. |
| 21 | Partition and filesystem verification | Orchestrate Apple's verification utilities and interpret their results. Mounted/startup-volume behavior and permissions vary; verification can affect responsiveness. |
| 22 | Partition and volume repair | Initially guide users to First Aid/Recovery. Later consider narrow, separately authorized wrappers for supported non-startup targets. This is not a new filesystem repair engine. |
| 23 | APFS snapshots and restoration | Inventory first; later supported creation/mounting and copying selected files to a new destination. No automatic system rollback; snapshot existence does not make it an independent backup. |
| 24 | Volume cloning and synchronization | Data-volume copying with metadata preservation and verification is feasible. Bootable system duplication, consistent live-source copies, exclusions and deletion semantics need a separate backup-quality project. |
| 25 | Targeted cache/database rebuilds | Add only documented, symptom-specific operations with effects and postchecks. Each adapter needs OS-version tests; avoid a generic “clean everything” action or assumed speed benefit. |
| 26 | Surface/read-error scan | A finite read-only range scan on explicitly selected supported media is possible. Raw-device access and long runtimes complicate it; logical reads cannot inspect every hidden/remapped flash cell. Avoid stressing a drive already suspected of failing. |

Evidence for the boundaries:

- The installed `diskutil(8)` manual documents `verifyVolume`, `verifyDisk`, `repairVolume`, and APFS `listSnapshots -plist`. It says live repair of a writable mounted volume is unsupported and repair generally needs unmounting. Apple's [First Aid guidance](https://support.apple.com/en-us/102611) directs startup-disk repair to Recovery.
- The installed `tmutil(8)` manual says some operations require both root and Full Disk Access. These are separate capabilities; neither is granted merely by notarization.
- The installed `powermetrics(1)` manual documents finite sample counts, platform-dependent sensors, and estimated energy metrics. Its older Intel-centric explanations are not proof of current Apple silicon field coverage.
- Apple's [thermal-state guidance](https://developer.apple.com/documentation/xcode/responding-to-power-notifications) supports broad thermal assessment. It does not provide a universal catalogue of temperature/voltage/fan tests.
- Apple's [Metal memory documentation](https://developer.apple.com/documentation/metal/mtldevice/hasunifiedmemory) explicitly distinguishes shared and dedicated memory.
- [Micromat's APFS explanation](https://www.micromat.com/apfs-support-status-13/) itself describes limits on full rebuilding and optimization. Treat the linked support article as a statement of constraints, not an independently tested current implementation guarantee.

## Four features to defer or omit

| # | Capability | Assessment |
| --- | --- | --- |
| 27 | Disk initialization/repartitioning | Technically buildable through macOS tools, but duplicates Disk Utility and expands destructive-action scope with little benefit to symptom diagnosis. Prefer a guided handoff. |
| 28 | Deleted-file scavenging/deep recovery | A specialized storage-recovery product: filesystem knowledge, damaged-media handling and extensive fixtures. Encryption, overwrites and SSD deallocation constrain recovery. Offer backup/snapshot recovery paths first. |
| 29 | Secure file/free-space wiping | Do not promise irrecoverable deletion through repeated file overwrites on modern storage. Apple's [erase guidance](https://support.apple.com/en-nz/guide/disk-utility/-dskutl14079/mac) says SSD secure-erase options are unavailable in Disk Utility. Guide whole-device retirement through the appropriate Apple workflow. |
| 30 | Legacy maintenance scripts | Little value for the current direction. The Techtool manual marks its System Maintenance tool unavailable on macOS Sequoia and later. Do not present obsolete scheduled scripts as necessary modern maintenance. |

## Recommended build order

1. **Broader on-demand diagnosis:** storage capacity and exposed drive status, battery/power information, thermal state, and system memory-pressure/swap context. Memory pressure is an additional Lucius priority, distinct from destructive or intensive RAM testing. Preserve the current quiet idle behavior.
2. **Useful explanations:** app/security inspection, network checks, richer reports, and explicit Quick/Deep suites. Tie observations to symptoms without treating correlation as cause.
3. **Storage investigation:** snapshot inventory, selected-file validation, filesystem verification and optional disk benchmarks. Keep long checks separate from the quick scan.
4. **Separately scoped advanced work:** narrowly defined repairs, supported hardware adapters and opt-in monitoring after measuring overhead. Recovery/cloning should not delay the first three stages.

This sequence adds the most useful everyday coverage while retaining Lucius's Scan → Explain → Repair → Verify workflow. A new generic diagnostic interface should sit beside the existing process component catalog: target identity, capability availability, required access, impact, time/output budgets, evidence, and verification. Keep diagnostic findings separate from repair authorization. Reuse the UI and incident concepts without forcing disks, batteries and network interfaces into a process-only model.

Before implementation commitments, run small read-only compatibility probes on the supported Mac/OS matrix for battery fields, drive status, sensor availability and snapshot access. Budget separately for a signed/notarized release and any narrow privileged helper. All subprocesses must be owned, bounded and reaped; mutating disk operations need their own safe completion/cancellation design rather than arbitrary forced termination.

Research verification: checked current vendor and Apple sources, local source files, and local macOS utility manuals. No repair, benchmark, stress test, monitor, or background process was started. No new dependencies or API costs were introduced.
