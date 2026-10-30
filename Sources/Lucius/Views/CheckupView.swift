import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LuciusCore

struct CheckupView: View {
    @Bindable var store: ScanStore
    @State private var notice: String?
    @State private var choosingPlan = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR MAC, IN FOCUS").eyebrow()
                    Text("A clearer picture. A next step.").font(.system(size: 30, weight: .semibold))
                    Text("Start with a guided checkup, or open a specific tool from the sidebar.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                }
                if store.isCheckingUp { runningPanel }
                else if store.displayedCheckup != nil {
                    DisclosureGroup("Start another checkup · choose coverage", isExpanded: $choosingPlan) {
                        plans.padding(.top, 16)
                    }.font(.system(size: 14, weight: .medium))
                } else { plans }
                if !store.isCheckingUp, let report = store.displayedCheckup {
                    HStack {
                        Picker("Saved checkup", selection: Binding(get: { report.id }, set: { store.selectedCheckupID = $0 })) {
                            ForEach(store.checkupReports) { item in
                                Text("\(item.plan.title) · \(item.completedAt.formatted(date: .abbreviated, time: .standard))").tag(item.id)
                            }
                        }.frame(maxWidth: 470)
                        Spacer()
                        Button("Export report…") { export(report) }.buttonStyle(ActionButton())
                    }
                    if let notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
                    CheckupResultsView(report: report)
                } else if !store.isCheckingUp {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Useful evidence, without the guesswork", systemImage: "text.magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Your results will separate findings to review, available observations and checks that could not finish. Each result explains what it can tell you.")
                            .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(4)
                        Text("Nothing runs until you start it. Reports stay on this Mac.").font(.callout)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).panel()
                }
                HStack(spacing: 18) {
                    Label("On demand", systemImage: "hand.tap")
                    Label("Saved locally", systemImage: "internaldrive")
                    Label("You control recovery", systemImage: "hand.raised")
                }.font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private var plans: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(CheckupPlan.allCases) { plan in
                VStack(alignment: .leading, spacing: 16) {
                    Label(plan == .quick ? "START HERE" : "GO FURTHER", systemImage: plan == .quick ? "sparkle.magnifyingglass" : "cpu")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(plan == .quick ? Theme.cyan : Theme.violet)
                    Text(plan.title).font(.system(size: 23, weight: .semibold))
                    Text(plan.subtitle).font(.system(size: 14)).frame(minHeight: 36, alignment: .topLeading)
                    Text(plan.coverage).font(.system(size: 13)).foregroundStyle(.secondary)
                        .lineSpacing(4).frame(minHeight: 50, alignment: .topLeading)
                    Text(plan == .quick ? "Lightweight observations · no test workloads" : "Brief CPU / GPU load · 64 MiB RAM · 10s sensor sample")
                        .font(.system(size: 12)).foregroundStyle(.secondary).frame(minHeight: 32, alignment: .topLeading)
                    Button("Start \(plan.title.lowercased())") { notice = nil; choosingPlan = false; store.startCheckup(plan) }
                        .buttonStyle(ActionButton(primary: plan == .quick)).disabled(store.isBusy)
                }.padding(24).frame(maxWidth: .infinity, alignment: .topLeading).panel()
            }
        }
    }

    private var runningPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.checkupPlan.title).font(.title2.weight(.semibold))
                    Text(store.isCancelling ? "Stopping · waiting for the current check to exit…" : store.checkupPhase)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.isCancelling ? "Stopping…" : "Stop checkup") { store.cancel() }
                    .buttonStyle(ActionButton()).disabled(store.isCancelling)
            }
            RunProgress(value: store.checkupProgress, color: Theme.cyan)
            Text("Step \(store.checkupStepIndex + 1) of \(store.checkupPlan.steps.count) · progress follows completed work, not a time estimate")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(store.checkupPlan.steps.enumerated()), id: \.element.id) { index, step in
                let result = store.checkupResults.first { $0.step == step }
                HStack {
                    Label(step.title, systemImage: step.symbol)
                    Spacer()
                    Text(result?.summary ?? (index == store.checkupStepIndex ? "Running" : "Queued"))
                        .foregroundStyle(result?.state == .unavailable ? Theme.amber : Theme.dim)
                }.font(.system(size: 13))
            }
        }.padding(24).panel()
    }

    private func export(_ report: CheckupReport) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Lucius-checkup.md"
        panel.message = "Reports may include device and volume names. Review before sharing."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try report.markdown.write(to: url, atomically: true, encoding: .utf8); notice = "Report saved." }
            catch { notice = "Export failed: \(error.localizedDescription)" }
        }
    }
}

private struct CheckupResultsView: View {
    let report: CheckupReport
    private var nextStep: String {
        if !report.completed { return "Completed steps are preserved below. Start another checkup when ready, or use Hardware tests to run an unfinished workload separately." }
        if report.reviewCount > 0 { return "Start with the highlighted findings below. Each explains the observation and its limits." }
        return "If your symptom continues, use Component scan for a longer observation or review the detailed results below. A quiet sample cannot rule out a problem."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(report.headline).font(.system(size: 23, weight: .semibold))
                Text("\(report.plan.title) · \(report.completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    Label("\(report.reviewCount) to review", systemImage: "exclamationmark.circle")
                    Label("\(report.unavailableCount) unavailable", systemImage: "questionmark.circle")
                    Label(report.completed ? "Run finished" : "Partial coverage", systemImage: report.completed ? "checkmark.circle" : "stop.circle")
                }.font(.system(size: 13))
                Text(nextStep)
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(3)
                if report.unavailableCount > 0 {
                    Text("Unavailable means Lucius could not assess that item; it does not mean it failed.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).panel()
            ForEach(report.findings.filter { $0.status == .attention }) { finding in DiagnosticCard(finding: finding) }
            ForEach(report.results.compactMap(\.hardware).filter { $0.outcome == .failed }) { result in HardwareResultCard(result: result) }
            ForEach(report.results) { result in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if !result.detail.isEmpty { Text(result.detail).font(.callout).foregroundStyle(.secondary) }
                        ForEach(result.findings) { finding in DiagnosticCard(finding: finding) }
                        if let hardware = result.hardware { HardwareResultCard(result: hardware) }
                    }.padding(.top, 14)
                } label: {
                    HStack {
                        Label(result.step.title, systemImage: result.step.symbol)
                        Spacer()
                        Text(result.summary).foregroundStyle(.secondary)
                    }.font(.system(size: 14, weight: .medium))
                }.padding(18).panel()
            }
        }
    }
}
