# Lucius

A native, on-demand Mac diagnostic app and component scanner inspired by Lucius Fox's sonar screen wall.

## Run

Build and open the app (requires macOS 14+ and Swift 6):

```sh
./script/build_and_run.sh
```

The script builds a SwiftPM executable, packages a local `.app`, signs it ad hoc, and opens it. It only stops an existing process whose executable matches this workspace's bundled app. `--build-only` packages without opening; `--verify` also checks launch; `--stop` closes this workspace's app. `--debug`, `--logs`, and `--telemetry` are interactive developer modes; stop them with Ctrl-C.

Requires macOS 14+ and the Swift 6 compiler. No third-party packages or network credentials are needed. This is a local preview, not a Developer ID-signed or notarized public release. The app runs outside App Sandbox so macOS can permit inspection and user-requested process control.

## Guided checkups (0.4)

Lucius opens in **Checkup**. Quick checkup combines the six-component scan with memory/thermal, storage and power observations. Extended checkup adds network interfaces, security settings, hardware inventory and the four bounded hardware workloads. Coverage and resource use appear before starting; no recovery action runs automatically.

Each checkup runs sequentially, shows the active stage, and supports Stop or Command-period from any workspace. Completed stages survive cancellation; unfinished stages are marked Stopped or Not started. Findings needing review appear first; unavailable readings never become a pass. Reports contain detailed observations, workload results and sensor samples, with Markdown export. The last ten checkups persist in `~/Library/Application Support/Lucius/checkup-reports.json`.

The native sidebar groups Checkup, Tools and Library. History reopens saved reports. Command-Shift-R starts a quick checkup; Command-R starts the component scan. Settings remains available from the sidebar and app menu. Light remains the default, with Dark and Follow system options.

## What works

- Optional symptom field and suggestions; local keyword matching prioritizes components.
- Six one-second scan intervals covering Notification Center, Dock, Finder, Control Center, SystemUIServer, and Quick Look's UI service.
- Live cumulative CPU counters converted to percent of one core, physical memory footprint, process identities, and measurement timestamps.
- A blue-white sonar animation during active scans; static results afterward, plus Reduce Motion and a minimal-motion setting.
- A twelve-interval deeper check for one component, and cancellation.
- Notification Center restart with an explicit explanation, exact identity verification, normal TERM only, a bounded relaunch check, and a separate user confirmation of symptom recovery.
- Forty local incident summaries under `~/Library/Application Support/Lucius/incidents.json`.

## Diagnostics

The System overview sidebar offers a quick overview and custom selection of six read-only groups:

- Memory pressure (where exposed), installed memory, swap usage and macOS thermal state.
- Local volume capacity, with low-space review and shared APFS capacity context.
- Battery/UPS charge and available battery condition, cycle count and capacity.
- Active addressed network interfaces, without sending network probes.
- FileVault, System Integrity Protection and Gatekeeper configuration.
- OS, processor and Metal GPU inventory.

Inspect up to 10 selected local applications for bundle metadata, code signatures and executable architectures. Check up to 20 selected local JSON/plist files or PNG/JPEG/GIF headers, capped at 4 MiB per file. Image pixels and animation frames are not fully validated. These checks never launch selected apps or rewrite selected files.

Reports distinguish observed, review, unavailable and informational findings. Completed or partial reports can be exported as Markdown; exports can contain device, volume, application and file names. The last ten detailed overviews persist in `~/Library/Application Support/Lucius/diagnostic-reports.json` and reopen from System overview or History; compact run summaries join the 40-entry local history.

System command output and runtimes are capped. Cancellation and normal application quit stop and reap owned utility processes. No disk repair, recovery, cloning, wiping, cache cleanup, automatic repair or continuous monitor is included. Hardware workloads are separate from the read-only overview. The expanded roadmap is in `TECHTOOL-FEASIBILITY.md`.

## Hardware tests (0.3)

A separate Hardware tests workspace runs actual bounded workloads:

- **CPU:** up to two seconds of integer FNV-1a and exact floating-point known-answer checks on up to four concurrent workers; a fixed iteration ceiling also applies. Volatile accumulators prevent optimization from removing the workload.
- **RAM:** six write/read patterns over a 64 MiB allocation (384 MiB compared). Volatile accesses keep comparisons real; mismatch counts and first offset are recorded.
- **GPU:** four Metal compute passes, 8 MiB of shared buffers, every output compared with a CPU reference (4,194,304 values). Outputs are poisoned before dispatch to detect an unexecuted kernel.
- **Cooling:** eleven temperature/fan-RPM/thermal-state samples over ten seconds, with charts and raw readings. SMC access is read-only and model-dependent. Raw keys are not presented as calibrated component labels. M3 MacBook Air models are explicitly identified as fanless.

Every test runs in a separate packaged worker with a 20-second deadline, capped JSON-line output and dedicated process-group cleanup. Workload checkpoints stop on serious thermal pressure or elevated/unreadable memory pressure. Cancel and normal quit wait for worker cleanup. Crashes, missing workers, invalid output and deadlines do not become hardware failures or passes.

The last ten detailed hardware reports persist under `~/Library/Application Support/Lucius/hardware-reports.json`. Export includes workload coverage, model/OS context, metrics, duration, next steps and raw sensor samples. Prior completed results and explicit not-started outcomes are retained when a suite is cancelled.

These are bounded diagnostic samples, not burn-in tests or whole-machine certification. RAM coverage excludes memory outside the process allocation; GPU coverage excludes unallocated memory and unexercised functions. Direct fan-speed control is not implemented. No administrator or privileged helper is required.

For an opt-in host verification run (brief hardware load):

```sh
LUCIUS_HARDWARE_SMOKE=1 ./script/test.sh
```

The default test suite skips the hardware-load smoke. That smoke runs all four workloads, verifies cancellation, and writes `artifacts/hardware-smoke.md`. Metal/SMC and pressure readings need normal host access; restricted agent sandboxes may hide them.

## What the component scan means

“Observed” means a matching process was found and measured; it does not mean its UI responds. Three consecutive readings at or above 70% of one core produce “Elevated activity.” This is a heuristic, not a diagnosis. A low-CPU deadlock can go undetected. A missing process may be normal, inaccessible, or unsupported on this OS version. The component scan itself does not perform network or hardware diagnostics. The separate System overview and Hardware tests workspaces report their own explicit coverage; none certifies whole-Mac health.

Lucius does not inspect message content, capture the screen, stream logs, call AI services, monitor continuously, or run a privileged helper. The contour artwork is decorative; numeric metrics and sparklines use actual observations. Only Notification Center has a restart operation in this preview. Other components are inspection-only.

## Implementation

- `Sources/CProcess`: bounded libproc reads and identity-checked SIGTERM.
- `Sources/LuciusCore`: component catalog, CPU deltas, diagnostic adapters, bounded utility execution, report models, and scan/recovery workflows.
- `Sources/Lucius`: SwiftUI scenes, scan state, sonar canvas, details, settings, and local history.
- `Tests/LuciusCoreTests`: CPU arithmetic, conservative classification, symptom matching, cancellation, and process-control boundaries using a disposable child process.

The process identity includes user, exact executable path, PID, and start time. It is checked immediately before signaling. POSIX `kill` cannot atomically bind a signal to a start time, so a small residual PID-reuse race remains; the UI never offers arbitrary process termination or force-kill escalation.

## Tests

```sh
./script/test.sh
```

The test script uses full Xcode when installed, without changing global settings. Run process tests with normal host permissions; a restricted execution environment may prohibit process enumeration or signaling. The termination test owns a `/bin/sleep 20` child, rejects mismatched identities, sends TERM only to that child, and reaps it. Tests do not restart system components.

See `HANDOFF.md` for current verification and remaining limitations, and `LUCIUS-CONCEPT.md` for the original product direction.
