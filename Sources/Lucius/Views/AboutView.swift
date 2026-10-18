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
                section("Evidence, with its limits", "CPU is measured against one core; 100% means one core's worth of work, not the whole Mac. Three consecutive observations at or above 70% are flagged. That is a heuristic, not a diagnosis. A deadlock can use almost no CPU. Process presence and resource readings do not establish interface responsiveness.")
                section("You control recovery", "Only Notification Center has a restart action in this preview. Lucius verifies the current user, exact executable, process ID, and start time before requesting normal termination. It never escalates to force-kill. A new process and your confirmation are separate outcomes.")
                section("Quiet by default", "The sonar contours are an abstract illustration, not physical locations or additional measurements. Animation runs only during a visible scan and respects Reduce Motion. No account, network request, language model, or privileged helper is needed.")
                section("Local preview", "This is a locally built app, not a notarized public release. Component paths and process-control permissions can change across macOS versions. No clear issue found means this scan found no clear issue—not that every system is healthy.")
                Text("Lucius 0.1 · Built for macOS 14 and later").eyebrow()
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
    @AppStorage("minimalMotion") private var minimalMotion = false
    var body: some View {
        Form {
            Section("Scan appearance") {
                Toggle("Use minimal motion", isOn: $minimalMotion)
                Text("System Reduce Motion is also respected. Animation stops between scans.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy and activity") {
                LabeledContent("Background monitoring", value: "Off · not used")
                LabeledContent("Network access", value: "Not used")
                LabeledContent("History retention", value: "40 summaries on this Mac")
            }
        }.formStyle(.grouped).frame(width: 460, height: 290)
    }
}
