# Lucius

A native, on-demand Mac diagnostic app and component scanner inspired by Lucius Fox's sonar screen wall.

Private repository: [bennettschiff/lucius](https://github.com/bennettschiff/lucius).

## Run

Open `dist/Lucius.app`, or use Codex's **Run** action. To rebuild:

```sh
./script/build_and_run.sh
```

The script builds a SwiftPM executable, packages a local `.app`, signs it ad hoc, and opens it. It only stops an existing process whose executable matches this workspace's bundled app. `--build-only` packages without opening; `--verify` also checks launch; `--stop` closes this workspace's app. `--debug`, `--logs`, and `--telemetry` are interactive developer modes; stop them with Ctrl-C.

Requires macOS 14+ and the Swift 6 compiler. No third-party packages or network credentials are needed. This is a local preview, not a Developer ID-signed or notarized public release. The app runs outside App Sandbox so macOS can permit inspection and user-requested process control.

## What works

- Optional symptom field and suggestions; local keyword matching prioritizes components.
- Six one-second scan intervals covering Notification Center, Dock, Finder, Control Center, SystemUIServer, and Quick Look's UI service.
- Live cumulative CPU counters converted to percent of one core, physical memory footprint, process identities, and measurement timestamps.
- A blue-white sonar animation during active scans; static results afterward, plus Reduce Motion and a minimal-motion setting.
- A twelve-interval deeper check for one component, and cancellation.
- Notification Center restart with an explicit explanation, exact identity verification, normal TERM only, a bounded relaunch check, and a separate user confirmation of symptom recovery.
- Forty local incident summaries under `~/Library/Application Support/Lucius/incidents.json`.

## Diagnostics

The Diagnostics sidebar offers a quick overview and custom selection of six read-only groups:

- Memory pressure (where exposed), installed memory, swap usage and macOS thermal state.
- Local volume capacity, with low-space review and shared APFS capacity context.
- Battery/UPS charge and available battery condition, cycle count and capacity.
- Active addressed network interfaces, without sending network probes.
- FileVault, System Integrity Protection and Gatekeeper configuration.
- OS, processor and Metal GPU inventory.

Inspect up to 10 selected local applications for bundle metadata, code signatures and executable architectures. Check up to 20 selected local JSON/plist files or PNG/JPEG/GIF headers, capped at 4 MiB per file. Image pixels and animation frames are not fully validated. These checks never launch selected apps or rewrite selected files.

Reports distinguish observed, review, unavailable and informational findings. Completed or partial reports can be exported as Markdown; exports can contain device, volume, application and file names. The last report stays in memory until replaced or the app quits; compact run summaries join the 40-entry local history.

System command output and runtimes are capped. Cancellation and normal application quit stop and reap owned utility processes. No disk repair, recovery, cloning, wiping, cache cleanup, stress testing, automatic repair or continuous monitor is included. The expanded roadmap is in `TECHTOOL-FEASIBILITY.md`.

## What the component scan means

“Observed” means a matching process was found and measured; it does not mean its UI responds. Three consecutive readings at or above 70% of one core produce “Elevated activity.” This is a heuristic, not a diagnosis. A low-CPU deadlock can go undetected. A missing process may be normal, inaccessible, or unsupported on this OS version. The component scan itself does not perform network or hardware diagnostics. The separate Diagnostics view reports the limited checks listed above; neither mode certifies whole-Mac health.

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
