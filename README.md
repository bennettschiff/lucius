# Lucius

A native, on-demand Mac component scanner inspired by Lucius Fox's sonar screen wall.

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

## What the scan means

“Observed” means a matching process was found and measured; it does not mean its UI responds. Three consecutive readings at or above 70% of one core produce “Elevated activity.” This is a heuristic, not a diagnosis. A low-CPU deadlock can go undetected. A missing process may be normal, inaccessible, or unsupported on this OS version. No network, hardware, disk-health, or whole-Mac health test is performed.

Lucius does not inspect message content, capture the screen, stream logs, call AI services, monitor continuously, or run a privileged helper. The contour artwork is decorative; numeric metrics and sparklines use actual observations. Only Notification Center has a restart operation in this preview. Other components are inspection-only.

## Implementation

- `Sources/CProcess`: bounded libproc reads and identity-checked SIGTERM.
- `Sources/LuciusCore`: component catalog, CPU deltas, evidence classification, scan and recovery workflows.
- `Sources/Lucius`: SwiftUI scenes, scan state, sonar canvas, details, settings, and local history.
- `Tests/LuciusCoreTests`: CPU arithmetic, conservative classification, symptom matching, cancellation, and process-control boundaries using a disposable child process.

The process identity includes user, exact executable path, PID, and start time. It is checked immediately before signaling. POSIX `kill` cannot atomically bind a signal to a start time, so a small residual PID-reuse race remains; the UI never offers arbitrary process termination or force-kill escalation.

## Tests

```sh
./script/test.sh
```

The test script uses full Xcode when installed, without changing global settings. Run process tests with normal host permissions; a restricted execution environment may prohibit process enumeration or signaling. The termination test owns a `/bin/sleep 20` child, rejects mismatched identities, sends TERM only to that child, and reaps it. Tests do not restart system components.

See `HANDOFF.md` for current verification and remaining limitations, and `LUCIUS-CONCEPT.md` for the original product direction.
