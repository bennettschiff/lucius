# Lucius implementation handoff

Updated October 22, 2026. Lucius 0.3 native local preview. Source publication is authorized; public app distribution still needs Developer ID signing and notarization.

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
- Forty incident summaries. Overview reports still remain in memory until exported; hardware reports have separate durable storage.

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

Report storage: `~/Library/Application Support/Lucius/hardware-reports.json` (ten full reports) and `incidents.json` (forty summaries). No uploads or background monitoring. All app-owned workers must exit before task completion; normal quit handles this. An external SIGKILL of the app bypasses application cleanup and is not the supported shutdown path.

## Remaining limits and useful next work

- No direct fan-speed control. Techtool actively modulates fans; equivalent behavior needs validation on fan-equipped models and safe restoration of automatic control. This Mac has no fan.
- Temperature keys use an undocumented read-only SMC interface and a small bounded key set. Raw key names avoid unverified semantic labels; no calibrated diagnostic thresholds or cross-model compatibility guarantee.
- Passing CPU/RAM/GPU samples cannot rule out intermittent failures or faults outside tested operations/allocations. The GPU test does not validate pixels, codecs, all execution units or all VRAM. Apple Diagnostics remains a broader next step.
- Active DNS/network probes, Bonjour discovery, device-specific USB/Bluetooth/Thunderbolt tests, detailed SMART, complete media decoding and optional longer validated workloads remain future work. These have not been disguised as implemented checks.
- Disk repair/recovery/cloning/initialization/wiping and generic cleanup remain outside accepted scope. No Techtool feature-parity claim.
- Notification Center restart retains the small POSIX PID-reuse race documented in README; no new component recovery actions were added.

`TECHTOOL-FEASIBILITY.md` contains the original comparison plus a current implementation/coverage table. Future contributors should preserve unrelated changes, bounded process ownership and quiet idle behavior.
