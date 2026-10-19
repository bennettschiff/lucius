# Lucius implementation handoff

Updated October 19, 2026. Lucius 0.2 native local preview implemented and verified in this workspace. Source publication is authorized; public app distribution remains pending signing and notarization.

## Delivered

- SwiftPM app, staged as `dist/Lucius.app`, with a custom app icon and local ad-hoc signature.
- Codex Run action: `./script/build_and_run.sh`.
- On-demand scan, optional symptom input, four suggestions, local symptom prioritization, blue-white scan sweep and contours, a six-component overview, persistent inspection/repair actions, and local history.
- Native libproc identity and resource measurements. Six intervals for a general scan, twelve for a deeper check. Both are finite and cancellable.
- Notification Center is the only restartable component. Exact path, UID, PID, and start time are revalidated, TERM is used without escalation, replacement is checked within ten seconds, and symptom resolution is separately confirmed by the user.
- Other components: Dock, Finder, Control Center, SystemUIServer, and Quick Look UI. Inspection only.
- Diagnostics sidebar with quick/custom system groups: memory pressure/swap, thermal state, local capacity, battery/UPS information, interface enumeration, three security configuration checks, and OS/CPU/GPU inventory.
- Selected local application inspection (10 app maximum): bundle metadata, signature verification, main-executable architecture. Selected file validation (20 file maximum, 4 MiB per file): JSON/plist syntax or PNG/JPEG/GIF container/header metadata.
- Timestamped findings, review/unavailable counts, partial results, Markdown export and compact local history summaries. Full reports stay in memory until replaced or quit; exporting is explicit.
- Diagnostic utilities use a dedicated process group, a capped nonblocking output pipe, finite deadlines and cleanup of owned descendants. Normal quit awaits cancellation/cleanup. SIGKILL fallback applies only to task-owned diagnostic utilities, never to a component recovery target.
- No continuous monitoring, login helper, privileged service, network probes, third-party packages, or AI costs. Disk repair, recovery, cloning, initialization, wiping and generic cleanup are excluded from the accepted scope.

## Verification

- Build and native bundle launch succeeded on this Apple silicon Mac running macOS 27.0.1.
- `./script/test.sh`: 17 XCTest cases passed, 0 failures, including a final run with normal host access. CPU math, process replacement, missing/ambiguous metrics, sustained-versus-transient high CPU, symptom ordering, scan cancellation, name-only impostor rejection, own-process metrics, and identity-checked termination of a disposable `/bin/sleep 20` child are covered.
- New tests cover unknown pressure/invalid capacity handling, utility output limits, timeout/cancellation reaping, descendant cleanup, file size/symlink limits, read-only validation, partial-report serialization, and live category coverage.
- Full-host diagnostic smoke returned 14 observations across six groups. Battery health fields were checked against actual system-profiler output, including the capacity key. Sandbox runs correctly marked pressure/swap, FileVault and Metal unavailable where access was denied; normal-host runs read those values.
- GUI verified the diagnostic layout, a 14-observation full scan, seven-observation quick preset, selected Lucius.app metadata/signature/arm64 result, selected JSON fixture, saved Markdown report and local history. Report output was read back from ignored `artifacts/Lucius-diagnostics.md`. Its numbers are historical QA observations, not current health claims.
- `./script/build_and_run.sh --verify` successfully packaged, signed and launched version 0.2. Final app/file inspections and quick scan used the packaged app; task-owned GUI and command sessions were closed after QA.
- Live GUI scan returned measurements for all six components. Notification Center was observed at approximately 0% CPU during those scans; this does not recreate or diagnose the earlier hang.
- A later scan observed multiple Quick Look instances and conservatively reported Multiple matches with 5 of 6 components measured.
- GUI checks: notification and preview symptom selection; completed six-component scans; a completed twelve-interval targeted check; Command-period cancellation; persisted history across relaunch; Notification Center restart explanation and Cancel. No system component was restarted during testing.
- Visual inspection confirmed the dark sonar treatment, active scan sweep, live metrics, and an inspector that scrolls while its action buttons remain visible.
- Performance spot checks from the initial preview build: 15-second idle average 0.004% of one CPU core, peak physical footprint 71.28 MiB. A separate 15-second window spanning a deeper scan and subsequent idle showed about 1.0–1.1% CPU during active samples, a 136.64 MiB peak, and a return to about 55.6 MiB with near-zero CPU afterward. These are short observations, not a 15-minute energy/GPU benchmark or a guarantee across machines. Raw evidence is in ignored `artifacts/`.

## Toolchain

The selected Command Line Tools installation can build the app but lacks the SwiftUI State macro plugin and XCTest framework expected by some SDK paths. A small State property-wrapper alias avoids the macro requirement. Both scripts prefer the installed full Xcode when available, scoped to their process through DEVELOPER_DIR; global xcode-select was not changed. XCTest tests are used. There are no downloaded dependencies.

## Remaining limitations

- A resource scan cannot detect every hang, infer root cause, or establish UI responsiveness. A low-CPU deadlock can go undetected.
- The twelve-second deeper check gathers more resource observations; it does not capture or interpret a stack sample yet.
- Automatic repairs and additional component restart adapters are not implemented. Hardware inventory is not hardware testing; interface enumeration is not an internet/DNS probe.
- Detailed SMART, exact sensor temperatures/RPM, CPU/RAM/GPU stress tests, Bonjour discovery, active network probes, monitoring/email and benchmarks remain future work. No claim of Techtool feature parity is made.
- Selected app checks do not launch apps, establish notarization or prove malware safety. File checks do not validate image pixels/animation frames, app-specific schemas or every possible format. Files must be local and downloaded; unsupported, oversized and inaccessible inputs are reported explicitly.
- Full reports are not retained across app relaunch; users can export them before starting another run or quitting. The persistent history contains compact summaries only. There is no new performance/energy benchmark for version 0.2; earlier measurements above describe the initial component-only build.
- Notification Center's real relaunch/recovery path has not been exercised by this app against a live hang. Its termination guard was exercised against an owned fixture. POSIX signaling retains a small non-atomic PID-reuse race despite immediate identity revalidation.
- The deployment target is macOS 14, but only this Mac's macOS 27.0.1 environment has been tested. Intel builds and older OS releases are not verified.
- This is a local ad-hoc-signed build, not a notarized public release. Public distribution needs Developer ID signing, notarization, and a compatibility matrix.
- Reduce Motion and a manual minimal-motion preference are implemented; a broader accessibility and battery/GPU audit remains.
- Local history currently contains scan summaries created during QA. No message contents or screenshots are collected by Lucius.

## Process lifecycle

Build/test subprocesses and disposable fixture process groups are finite and have exited. Cancellation/timeout tests verified that task-owned children and descendants were gone. The QA app is closed at handoff; no Lucius monitor is left running. Open the app bundle or use Run to start it. Closing the last app window or Command-Q exits Lucius.

## Collaboration

Private source repository: https://github.com/bennettschiff/lucius. The diagnostics expansion includes source, tests and documentation. The user authorized committing and pushing these changes on October 19, 2026. Generated app bundles remain local; this is not a notarized public release. The original feasibility inventory is preserved in TECHTOOL-FEASIBILITY.md with the accepted scope and implementation update at the top. The initial publication includes source, tests, scripts, the product brief, and Codex Run configuration. Generated builds, diagnostic artifacts, and the two original design-reference PNGs remain local and are ignored by Git. Preserve those local references. Source modules separate UI, scan state, process access, and recovery so future contributors can work without expanding restart scope accidentally. Keep capability labels and verification claims tied to evidence.
