import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("THE IDEA BEHIND LUCIUS").eyebrow()
                Text("Understand what's stuck.\nKeep working.").font(.system(size: 38, weight: .ultraLight)).lineSpacing(8)
                Text("Your Mac is made of many small systems. When one gets stuck, the answer can be smaller than a full restart.")
                    .font(.system(size: 16)).foregroundStyle(Theme.dim).lineSpacing(6)
                section("Scan on your terms", "Lucius takes six one-second observations of six supported interface components. Describe a symptom to prioritize the relevant component, or scan without one. Deeper checks observe one component for twelve intervals. Nothing monitors continuously in the background.")
                section("Broader diagnostics", "Diagnostics adds selectable memory, thermal, storage capacity, battery/UPS, network interface, security configuration, and hardware inventory checks. You can also inspect selected app signatures and validate small local JSON/plist files or image headers. Results distinguish observations, review items, unavailable checks and information. Export a local report when needed.")
                section("Actual hardware workloads", "Hardware tests adds bounded CPU known-answer checks, six RAM write/read patterns, four verified Metal compute passes and a ten-second temperature/fan-RPM observation. Supported sensors vary by Mac. Fan speed is never changed. The last ten detailed reports are saved locally and can be exported. A pass covers the completed workload only.")
                section("Evidence, with its limits", "CPU is measured against one core; 100% means one core's worth of work, not the whole Mac. Three consecutive observations at or above 70% are flagged. That is a heuristic, not a diagnosis. A deadlock can use almost no CPU. Process presence and resource readings do not establish interface responsiveness.")
                section("You control recovery", "Only Notification Center has a restart action in this preview. Lucius verifies the current user, exact executable, process ID, and start time before requesting normal termination. It never escalates to force-kill. A new process and your confirmation are separate outcomes.")
                section("Quiet by default", "The sonar contours are an abstract illustration, not physical locations or additional measurements. Animation runs only during a visible scan and respects Reduce Motion. No account, network probe, language model, or privileged helper is needed. Diagnostic utilities run only during a requested check and stop on cancellation or quit.")
                section("Local preview", "This is a locally built app, not a notarized public release. Component paths and process-control permissions can change across macOS versions. No clear issue found means this scan found no clear issue—not that every system is healthy.")
                Text("Lucius 0.3 · Built for macOS 14 and later").eyebrow()
            }.frame(maxWidth: 740, alignment: .leading).padding(40)
        }
    }
    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 16, weight: .medium))
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(5)
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "light"
    @AppStorage("minimalMotion") private var minimalMotion = false
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Follow system").tag("system")
                }
                Toggle("Use minimal motion", isOn: $minimalMotion)
                Text("System Reduce Motion is also respected. Activity animations stop between checks.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy and activity") {
                LabeledContent("Background monitoring", value: "Off · not used")
                LabeledContent("Network access", value: "Not used")
                LabeledContent("History retention", value: "40 summaries + 10 hardware reports")
            }
        }.formStyle(.grouped).frame(width: 460, height: 340)
    }
}
