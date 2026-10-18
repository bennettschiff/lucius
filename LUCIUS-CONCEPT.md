# Lucius

Product concept and initial engineering scope — October 18, 2026.

Status: this document records the product direction. A native local preview is now implemented; see HANDOFF.md for delivered scope, verification, and limitations. No system components were restarted during implementation testing.

## Purpose

Help a capable Mac user understand which background component powers a broken feature, inspect the evidence, and recover that component when a tested repair is available.

Product promise: **Understand what is stuck. Restore what you can. Keep working.**

The visual reference is Lucius Fox's sonar screen wall in The Dark Knight: an organized overview of many systems, with the ability to focus on one. The user explicitly wants the scan itself to resemble the reference's visual language. Use blue-white luminous outlines, granular depth, dark negative space, and multiple framed views. Animate this treatment during an on-demand scan, then settle into readable, still results. Retain native macOS navigation, keyboard access, accessibility, and a light appearance option.

## Founding incident

Source: user-supplied `notification-center-restart-app-idea.md` and screenshots, describing October 17, 2026. These are historical evidence, not measurements made today.

- A notification banner remained on screen; the user reported a spinning cursor when trying to interact with it.
- Messages continued working.
- The earlier report recorded Notification Center at approximately 100% of one CPU core and a three-second sample consistent with a hang in interface/layout code.
- The earlier intervention verified the executable and user, sent TERM to that specific process, and observed a replacement PID and CPU settling to 0%.
- The user confirmed the banner disappeared. The precise original trigger was not established.

Screenshots establish the visible symptom. CPU and stack evidence come from the supplied report. Neither should be presented as a live finding in a prototype.

## The experience

The primary workflow is **Scan → Explain → Repair → Verify**, initiated by the user when something feels wrong. Continuous monitoring is deferred beyond the first version.

The scan entry screen includes an optional **What's happening?** field with suggested symptoms such as “A notification is stuck,” “Dock won't respond,” “Previews won't open,” and “My Mac feels slow.” Allow free text and an **I'm not sure — scan everything supported** path. The user explicitly accepted this feature. A symptom prioritizes relevant checks without asserting a diagnosis or requiring the user to know a process name. Initial matching can use local rules and synonyms; unknown text must not silently map to a confident diagnosis.

**Scan my Mac** takes a short, bounded series of observations across supported components. Show actual scan stages, cancellation, and any skipped or unavailable checks. Offer a separate, bounded deeper check when the first scan cannot explain a reported symptom. A completed scan with no finding says **No clear issue found**, not “Everything is healthy.”

A secondary **System overview** lets the user browse supported components grouped by desktop, notifications, files and previews, audio, connectivity, and background activity. Explain coverage; never imply every macOS subsystem is fully observable or repairable.

Select a component to see what it does, what depends on it, its latest observations, when those observations were collected, and available actions. Keep executable names and diagnostic details in an expandable technical section.

The initial Notification Center flow:

1. User chooses “A notification is stuck.”
2. Lucius identifies the current user's Notification Center process and takes a short measurement.
3. It describes the observation: for example, “Sustained high CPU; you reported an unresponsive banner.” High CPU alone does not prove a hang.
4. Optional bounded diagnostic sampling gathers additional evidence if permitted.
5. Before repair, explain that notification UI will briefly disappear and that the expected outcome is a fresh Notification Center process. Do not promise universal behavior across macOS versions.
6. User chooses “Restart Notification Center.”
7. Revalidate process identity immediately before termination. Request normal termination of only the verified target; no automatic force-kill escalation.
8. Wait a bounded period for a verified replacement process and take a fresh measurement. Report timeout or permission failure honestly.
9. Ask whether the banner cleared. Record “process restarted” separately from “visible problem resolved.”

## Scan visual direction

Reference: [The Dark Knight — High Frequency Generator Scene](https://www.youtube.com/watch?v=IRELLH86Edo). The linked page and selected frames were inspected in the browser on October 18, 2026; the screen-wall frame around 00:16 shows blue-white translucent scene contours across individually framed panels. This is a reference inspection, not a frame-by-frame motion analysis of the full clip.

The proposed Lucius treatment translates the reference into a legible system map. The sequence below is a design proposal, not a claim that these exact effects occur in the clip:

1. **Ready:** a dark, quiet field contains faint outlined panels for supported component groups. The symptom field and Scan my Mac button remain the main controls.
2. **Scan starts:** a soft blue-white wave passes across the map. Fine dots and contour lines resolve into the component panels, giving a sense of revealing hidden structure.
3. **Checks run:** the active component gains depth and a restrained glow. Small echoes travel through verified relationships only; do not invent dependencies for visual decoration. A text line names the real current check. Decorative pulses do not imply successful measurements.
4. **Finding appears:** an affected panel receives an amber outline and a plain-language label such as “Needs a closer look.” Camera-like focus may gently bring that panel forward without hiding the rest of the map. Retain readable names and keyboard selection throughout.
5. **Scan ends:** motion settles and results stay visible. Show what was checked, what remains unknown, and the available next action. No fake percentage or delay to finish a cinematic sequence.
6. **Repair verification:** a short, localized sweep accompanies the actual recheck. Display “Process restarted” separately from the user's confirmation that the symptom cleared.

The map represents software components, not literal physical locations inside the Mac. Sound is off by default. Avoid flashing, aggressive glitch effects, continuous camera movement, and text rendered as grainy imagery. An accessible list exposes the same information, and Reduce Motion replaces the traveling sweep and focus movement with static highlights.

Prototype the effect with a bounded native drawing surface and a capped particle count; begin with a 30 fps ceiling while visible and scanning. Stop animation scheduling when idle or hidden. Measure GPU and energy costs as well as CPU and memory before choosing more complex rendering. The desired cinematic treatment is limited to active work; the app remains quiet between scans.

## Coverage and repair scope

| Component family | Initial purpose | Repair scope |
| --- | --- | --- |
| Notification Center | First complete diagnostic and recovery flow | First candidate for tested, user-triggered repair |
| Dock and Finder | Explain desktop symptoms and inspect available observations | Add independently after testing effects and recovery on supported OS versions |
| Menu bar / Control Center | Explain ownership of specific UI features | Inspection first; validate each process mapping and operation |
| Quick Look / previews | Help distinguish preview trouble from the source app | Inspection first; workers and lifecycle vary |
| Audio, Bluetooth, networking | Show useful checks and likely areas to investigate | Guided diagnostics initially; permissions and interruption costs vary |
| Core session / protected services | Explain limitations when relevant | No generic restart action |

This is a candidate catalog, not a verified list of restartable services. Inventory visibility, diagnostic coverage, and repair support are separate capabilities.

## Honest status reporting

Keep process presence, resource observations, and responsiveness separate:

- **Running:** a matching process exists. This does not mean its UI responds.
- **Elevated activity:** sustained resource use exceeded a component-specific threshold. It may be legitimate work.
- **Possible issue:** multiple observations or the user's symptom suggest investigation.
- **Not currently running:** potentially normal for an on-demand service.
- **Unknown / access limited:** no reliable current assessment is available.
- **Recovered:** state exactly what was verified and whether the user confirmed symptom resolution.

Do not infer root cause from memory usage, a single CPU spike, or a process restart. Do not count ordinary on-demand exits as crashes. A quiet deadlock may consume almost no CPU and escape lightweight monitoring.

## Lightweight on-demand execution

Build a native Swift/SwiftUI app with a scan window and Settings. A menu-bar shortcut is optional; the first version does not require a continuously running helper or monitoring service. Launching the app shows the scan entry point; scanning begins on user action.

- Collect repeated observations only within a finite user-started scan or verification session. Return to idle when it ends; cancellation stops collection and animation.
- Prefer lifecycle events where useful during an investigation. App lifecycle events do not cover every daemon.
- Any later optional monitoring mode should be configurable per component and separately benchmarked. It is outside the first-version scope.
- Use in-process OS queries for routine metrics where access permits; avoid repeatedly spawning shell commands.
- Increase sampling temporarily for an explicit investigation, with a timeout and cancellation.
- Stop chart updates when the window is hidden; adapt work around sleep, wake, and battery conditions.
- Keep a bounded in-memory history; persist compact incident summaries with retention limits.
- Capture process samples only on demand initially. Bound their duration, output size, and subprocess lifetime.
- No continuous screen capture, log streaming, network dependency, or local language model is required for the core workflow.
- Show Lucius's own resource use on demand and the last scan time. Quitting ends task-owned helpers. No recurring resource polling is needed merely to display Lucius's own idle statistics.

Initial performance targets, subject to measurement: under 100 MB physical footprint with the dashboard closed and near-zero idle CPU with no periodic scan or animation work scheduled. These are design budgets, not measured claims. Benchmark idle behavior for 15 minutes and measure scan duration, peak footprint, CPU, GPU, wakeups, energy impact, and repeated-scan memory growth. A short active scan can use more resources than idle operation; it must remain bounded and responsive to cancellation.

## Recovery and distribution architecture

Separate the component catalog, observation service, assessment rules, recovery operations, and incident storage. Each component adapter declares supported macOS versions, identity checks, available observations, interruption effects, repair method, verification, and timeouts.

Apple documents termination of other running apps as incompatible with App Sandbox. The proposed distribution route is a directly distributed, Developer ID-signed and notarized app rather than assuming the restart feature fits the Mac App Store sandbox. Notarization does not grant process-control privileges.

Start with operations permitted as the current user; validate permissions on the target OS before committing to support. Avoid a privileged helper in the first version. If a later feature genuinely needs one, design and review it as a separate capability with narrowly scoped operations.

For recovery, use a fixed catalog of vetted operations. Verify user, executable identity, PID, and available process start identity immediately before acting; minimize and handle process-exit/PID-reuse races. Reject ambiguous matches. Do not expose arbitrary commands or signal-by-name across all users. Unsupported services remain inspectable or explicitly unavailable.

Automatic repair is a later, separate opt-in feature. It would need per-component rules, strong evidence, cooldowns, attempt limits, and clear interruption semantics. Anomaly detection alone never authorizes it.

## Build sequence and acceptance evidence

1. **Feasibility slice:** inspect and measure Notification Center on the target Mac without altering it; establish identity and permission behavior. Test the recovery state machine with a disposable fixture. Validate a real restart only during an explicitly initiated repair test.
2. **Native prototype:** optional symptom field, bounded on-demand scan, sonar-inspired scan visualization, system overview, Notification Center detail, user-triggered repair, result verification, and local history. Label demonstration data clearly; the visual demo must not imply it scanned the Mac.
3. **Coverage:** add a few components individually, with tested behavior and honest capability labels.
4. **Opt-in monitoring:** measure idle cost, detection delay, legitimate busy periods, and false alerts before expanding.

Acceptance must include permission denial, absent or ambiguous target, identity changes, no relaunch, successful relaunch with unresolved symptom, sleep/wake, and quitting during a check. Every diagnostic subprocess must terminate within its budget or be explicitly cancelled and reaped.

## Sources and implementation handoff

- Historical incident: the user-supplied `notification-center-restart-app-idea.md` and screenshots (local reference material, not included in the repository). Keep private message content out of examples and diagnostic exports.
- [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox) — restricted operations include terminating other apps.
- [Apple: Energy Efficiency Guide — Best Practices](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/BestPractices.html) — minimize polling and timers, prefer event-driven work, and avoid invisible UI updates.
- [Apple: Application termination notification](https://developer.apple.com/documentation/appkit/nsworkspace/didterminateapplicationnotification) — an event source for applicable applications, not a universal service health API.
- [Apple: Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/) — direct distribution signing and notarization.

Accepted direction: on-demand scanning, optional symptom input, and a sonar-inspired visual scan. Implementation status is maintained in HANDOFF.md; design proposals above are not all delivered capabilities. The initial native preview is built locally, with live read-only scans, conservative restart controls, and bounded tests.
