# Lucius implementation handoff

Updated October 30, 2026. Lucius 0.4 native local preview. Source commit and push to the private origin/master repository authorized on October 30. App packaging remains local; no public binary release. Public app distribution still needs Developer ID signing and notarization.

## October 30 UX review and guided checkups

- New default Checkup workspace provides quick read-only checks and an explicit extended plan with bounded CPU/RAM/GPU/cooling workloads. Existing component and system tools remain directly accessible; no new repair action or background monitor.
- `LuciusCore/Checkup.swift` owns a sequential, cancellable runner with injectable step execution, explicit stopped/not-started/unavailable states and durable aggregate reports. Each active worker retains its existing cleanup/deadline guarantees. Report summaries never certify machine health or turn missing evidence into a pass.
- A native keyboard-navigable sidebar groups Start, Tools and Library; Settings is discoverable. Global status exposes Show run and Stop across workspaces. Command-Shift-R starts a quick checkup.
- Last ten checkups and ten system reports now persist locally, alongside existing hardware reports and forty activity summaries. History opens full reports. Hardware selection now follows the newly started run, including menu-triggered runs; it no longer falls back to an older selected report on completion.
- Component labels increased to at least 11 points where previously 8–10; the screen scrolls, the inspector retains its own scrolling, minimum window size is 1040 × 700. Default-window layouts inspected in light and dark; a formal VoiceOver audit and manual minimum-size test remain outstanding.
- Report summaries appear before optional new-run controls. Review findings appear first. Dates, coverage and partial/unavailable states remain explicit. Global persistence warnings are visible from every workspace.
- Verification evidence and prioritized future opportunities are in `docs/UX-REVIEW-2026-10-30.md`. Export QA artifact is ignored at `artifacts/Lucius-checkup.md`. No secrets, accounts or external services were added.

## October 28 UI refresh

- Light is now the default; Settings offers Light, Dark and Follow system. Native semantic surfaces keep both appearances readable. Colored sidebar icons, component tiles and blue/purple/teal/orange hardware cards replace the monochrome dark treatment.
- Hardware run panel shows the active workload, real worker phase, per-test ring, overall progress, elapsed time and explicit queued/running/outcome states. Saved summaries carry their report date. No fabricated measurements or progress timers.
- System overview announces each category before it starts and displays actual completed-category progress. Selected app/file inspection shows activity and observation counts without inventing a percentage.
- A bottom activity bar stays visible across workspaces with status and cancellation. Stopping waits for the existing owned-worker cleanup before returning to idle.
- Symbol pulses and progress interpolation honor system Reduce Motion and the app's minimal-motion preference; pulses pause in inactive scenes. Elapsed display updates at most once per second only while a check is running. Existing scan visuals remain on demand.
- Verification: packaged build/launch; 25 XCTest cases passed, one opt-in hardware smoke skipped, zero failures. Separately ran all four packaged workloads through the UI: CPU/RAM/GPU passed and cooling recorded 11 samples. Checked light/dark settings, minimal-motion setting, cross-workspace status and cancellation from History; worker exited and stopped result was recorded. Idle spot-check after cancellation: 0.1% CPU, about 153 MiB RSS (a snapshot, not a leak test).
- Source commit and push to `origin/master` authorized on October 28. The UI refresh includes this handoff and its verification evidence. App packaging remains local at `dist/Lucius.app`; no installation elsewhere or public binary release.

## Delivered in 0.3

The earlier diagnostics workspace was primarily status/inventory. It is now named **System overview**. A separate **Hardware tests** workspace performs real bounded workloads:

- CPU FNV-1a and exact floating-point known-answer checks on up to four workers, up to two seconds each, with an 8,192-iteration ceiling. Volatile C accumulators prevent release optimization from eliminating the calculations.
- RAM: 64 MiB allocation, six write/read patterns, 384 MiB compared, mismatch count and first failing byte offset. Volatile accesses; no memory reclamation or physical-memory certification claim.
- GPU: four Metal compute passes over 8 MiB of buffers; all 4,194,304 outputs checked against CPU expectations. Poisoned output prevents a skipped kernel from passing on stale data.
- Cooling: eleven samples over ten seconds of available SMC temperatures/fan RPM and macOS thermal state. Swift Charts, raw readings and range summaries. No SMC writes. M3 Air models Mac15,12 and Mac15,13 are explicitly fanless; unknown models remain unknown.
- Detailed hardware reports with results, scope, duration, metrics, model/OS and samples; last ten retained locally, plus Markdown export. Cancelled suites retain completed results and mark remaining tests stopped/not started.
- Separate packaged `LuciusDiagnosticWorker` executable. Each child has an owned process group, 20-second deadline, capped output and validated JSON-line messages. Cancellation/normal quit waits for cleanup. A crash, malformed output or deadline cannot produce a hardware pass/failure claim.
- CPU/RAM/GPU checkpoints stop for serious thermal state or elevated/unreadable memory pressure. These are brief tests, not burn-in workloads.
- Stats MIT protocol attribution in `THIRD-PARTY-NOTICES.md`, copied into the app bundle. No downloaded package dependencies, privileged helper or API costs.

## Existing features retained

- Six-component process scan and twelve-interval targeted observations, symptom prioritization, sonar visuals, CPU/memory evidence and cancellation.
- Guarded Notification Center restart only: exact identity/UID/path checks, normal TERM, replacement verification, separate user confirmation of symptom resolution. Other components remain inspection-only.
- System overview: pressure/swap, thermal, volume capacity, battery/UPS, interfaces, security settings, OS/CPU/GPU inventory. App signature/architecture checks and bounded JSON/plist/image-header inspection.
- Forty incident summaries. Overview, checkup and hardware reports each have durable storage (ten reports per type).

## Verification

- `LUCIUS_HARDWARE_SMOKE=1 ./script/test.sh`: **26 XCTest cases passed, zero failures**, normal host access. Default suite skips the explicit hardware-load smoke.
- Hardware smoke: CPU 65,536 known-answer checks, zero mismatches; all six RAM patterns passed; 4,194,304 GPU outputs passed on Apple M3; eleven cooling samples with seven available temperature keys and nominal thermal state. These are historical QA observations, not a current machine-health certificate. Full result in ignored `artifacts/hardware-smoke.md`.
- Tests cover deliberately corrupted RAM, fixed CPU/GPU arithmetic fixtures, conservative pressure/thermal stops, unknown fan capability, split/truncated/wrong-test/duplicate protocol messages, report round-trip/coverage, worker cancellation and existing process/utility cleanup boundaries.
- Packaged app built, ad-hoc signed and launched. UI verified selectable tests, completed results, temperature chart/raw disclosure, no-fan fallback and report restoration after relaunch.
- Native Markdown export verified by reading back `artifacts/Lucius-hardware-tests.md`: model/OS, all four outcomes and eleven raw samples preserved.
- Normal Command-Q during active cooling stopped/reaped the worker, preserved CPU/RAM/GPU passes and saved cooling as Stopped. Process check after quit found no Lucius/worker/test processes.
- Tested on Mac15,13 (15-inch M3 MacBook Air, 16 GiB), macOS 27.0.1. SMC temperatures are accessible here; fan RPM cannot be validated on this fanless machine. Metal/SMC/pressure may be inaccessible inside an agent sandbox, so use normal host access for hardware QA.

## Build and operation

`./script/build_and_run.sh` builds and stages `dist/Lucius.app`, including a separately ad-hoc signed helper under `Contents/Helpers`. `--build-only`, `--verify`, `--stop` and interactive debug/log modes are documented in README. Scripts prefer installed full Xcode without changing global xcode-select. No unrelated process should be stopped.

Report storage under `~/Library/Application Support/Lucius/`: `hardware-reports.json`, `diagnostic-reports.json`, `checkup-reports.json` (ten full reports each), and `incidents.json` (forty summaries). No uploads or background monitoring. All app-owned workers must exit before task completion; normal quit handles this. An external SIGKILL of the app bypasses application cleanup and is not the supported shutdown path.

## Remaining limits and useful next work

- No direct fan-speed control. Techtool actively modulates fans; equivalent behavior needs validation on fan-equipped models and safe restoration of automatic control. This Mac has no fan.
- Temperature keys use an undocumented read-only SMC interface and a small bounded key set. Raw key names avoid unverified semantic labels; no calibrated diagnostic thresholds or cross-model compatibility guarantee.
- Passing CPU/RAM/GPU samples cannot rule out intermittent failures or faults outside tested operations/allocations. The GPU test does not validate pixels, codecs, all execution units or all VRAM. Apple Diagnostics remains a broader next step.
- Active DNS/network probes, Bonjour discovery, device-specific USB/Bluetooth/Thunderbolt tests, detailed SMART, complete media decoding and optional longer validated workloads remain future work. These have not been disguised as implemented checks.
- Disk repair/recovery/cloning/initialization/wiping and generic cleanup remain outside accepted scope. No Techtool feature-parity claim.
- Notification Center restart retains the small POSIX PID-reuse race documented in README; no new component recovery actions were added.

`TECHTOOL-FEASIBILITY.md` contains the original comparison plus a current implementation/coverage table. Future contributors should preserve unrelated changes, bounded process ownership and quiet idle behavior.
