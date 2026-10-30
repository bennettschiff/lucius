import SwiftUI

struct HistoryView: View {
    let store: ScanStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("LOCAL RECORD").eyebrow()
            Text("Reports & history").font(.system(size: 30, weight: .semibold))
            Text("Reopen your last 10 reports of each type, or browse 40 activity summaries. Saved on this Mac.").font(.system(size: 13)).foregroundStyle(Theme.dim)
            if let notice = store.persistenceNotice { Text(notice).foregroundStyle(Theme.amber).font(.system(size: 12)) }
            if store.incidents.isEmpty && store.checkupReports.isEmpty && store.diagnosticReports.isEmpty && store.hardwareReports.isEmpty {
                ContentUnavailableView("No scans yet", systemImage: "clock.arrow.circlepath", description: Text("Run your first scan to start a local history."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if !store.checkupReports.isEmpty {
                            Text("CHECKUPS").eyebrow()
                            ForEach(store.checkupReports) { report in
                                reportButton(report.plan.title, date: report.completedAt, detail: report.headline) {
                                    store.selectedCheckupID = report.id; store.section = .home
                                }.disabled(store.isCheckingUp)
                            }
                        }
                        if !store.diagnosticReports.isEmpty {
                            Text("SYSTEM OVERVIEWS").eyebrow().padding(.top, 8)
                            ForEach(store.diagnosticReports, id: \.startedAt) { report in
                                reportButton("System overview", date: report.completedAt,
                                             detail: "\(report.completed ? "Finished" : "Partial") · \(report.reviewCount) to review · \(report.unavailableCount) unavailable") {
                                    store.showDiagnosticReport(report)
                                }.disabled(store.isDiagnosing)
                            }
                        }
                        if !store.hardwareReports.isEmpty {
                            Text("HARDWARE REPORTS").eyebrow().padding(.top, 8)
                            ForEach(store.hardwareReports) { report in
                                reportButton("Hardware tests", date: report.date, detail: report.results.map { "\($0.test.rawValue.uppercased()): \($0.outcome.rawValue)" }.joined(separator: " · ")) {
                                    store.selectedHardwareID = report.id; store.section = .hardware
                                }.disabled(store.isTesting)
                            }
                        }
                        Text("ACTIVITY SUMMARIES").eyebrow().padding(.top, 8)
                        ForEach(store.incidents) { incident in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: incident.title.contains("restart") ? "arrow.clockwise" : "viewfinder")
                                    .foregroundStyle(Theme.cyan).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(incident.title).font(.system(size: 14, weight: .medium))
                                    Text(incident.detail).font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(3)
                                }
                                Spacer()
                                Text(incident.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.dim)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).panel()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(38)
    }

    private func reportButton(_ title: String, date: Date, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(18).contentShape(Rectangle()).panel()
        }.buttonStyle(.plain).help("Open saved report")
    }
}
