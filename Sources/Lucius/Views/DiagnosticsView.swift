import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LuciusCore

struct DiagnosticsView: View {
    @Bindable var store: ScanStore
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SYSTEM DIAGNOSTICS").eyebrow()
                        Text("System overview").font(.system(size: 29, weight: .semibold))
                        Text(store.diagnosticPhase).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    }
                    Spacer()
                    if store.isDiagnosing {
                        Button(store.isCancelling ? "Stopping…" : "Cancel") { store.cancel() }.buttonStyle(ActionButton()).disabled(store.isCancelling)
                    } else {
                        Button { store.startDiagnostics() } label: { Label("Run checks", systemImage: "waveform.path.ecg") }
                            .buttonStyle(ActionButton(primary: true)).disabled(store.isBusy || store.selectedChecks.isEmpty)
                    }
                }
                if store.isDiagnosing { DiagnosticsRunPanel(store: store) }
                checkSelection
                selectedChecks
                if !store.isDiagnosing && !store.diagnosticReports.isEmpty {
                    Picker("Saved overview", selection: Binding(get: { store.diagnosticReport?.startedAt ?? store.diagnosticReports[0].startedAt }, set: { date in
                        if let report = store.diagnosticReports.first(where: { $0.startedAt == date }) { store.showDiagnosticReport(report) }
                    })) {
                        ForEach(store.diagnosticReports, id: \.startedAt) { report in
                            Text(report.completedAt.formatted(date: .abbreviated, time: .standard)).tag(report.startedAt)
                        }
                    }.frame(maxWidth: 420)
                }
                if !store.diagnosticFindings.isEmpty { findings }
                else if !store.isDiagnosing {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Observations you can act on", systemImage: "scope").font(.system(size: 17, weight: .medium))
                        Text("Start with a quick overview, choose specific systems, or inspect an app or file. Results explain what was measured and where a closer look may help.")
                            .font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(5)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).panel()
                }
                Text("Read-only, on demand. No disk repairs, cleanup, stress tests or background monitoring. Unavailable checks stay unknown; this scan does not certify hardware health.")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(4)
            }.padding(32)
        }
    }

    private var checkSelection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("CHOOSE YOUR COVERAGE").eyebrow()
                Spacer()
                Button("Quick overview") { store.selectedChecks = [.resources, .storage, .power] }
                Button("All system checks") { store.selectedChecks = Set(DiagnosticCategory.systemChecks) }
            }.buttonStyle(.borderless).font(.system(size: 11)).disabled(store.isBusy)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                ForEach(DiagnosticCategory.systemChecks, id: \.self) { category in
                    Toggle(isOn: Binding(get: { store.selectedChecks.contains(category) }, set: {
                        if $0 { store.selectedChecks.insert(category) } else { store.selectedChecks.remove(category) }
                    })) {
                        Label(category.rawValue, systemImage: category.symbol).font(.system(size: 12))
                    }.toggleStyle(.checkbox).disabled(store.isBusy)
                }
            }
        }.padding(20).panel()
    }

    private var selectedChecks: some View {
        HStack(spacing: 12) {
            Button { choose(applications: true) } label: { Label("Inspect apps…", systemImage: "app.badge.checkmark") }
                .buttonStyle(ActionButton()).disabled(store.isBusy)
            Button { choose(applications: false) } label: { Label("Check files…", systemImage: "doc.text.magnifyingglass") }
                .buttonStyle(ActionButton()).disabled(store.isBusy)
            Spacer()
            if store.diagnosticReport != nil {
                Button { exportReport() } label: { Label("Export report…", systemImage: "square.and.arrow.up") }
                    .buttonStyle(ActionButton()).disabled(store.isBusy)
            }
        }
    }

    private var findings: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                metric("OBSERVATIONS", store.diagnosticFindings.count, Theme.cyan)
                metric("TO REVIEW", store.diagnosticFindings.filter { $0.status == .attention }.count, Theme.amber)
                metric("UNAVAILABLE", store.diagnosticFindings.filter { $0.status == .unavailable }.count, Theme.dim)
                Spacer()
                if let report = store.diagnosticReport {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(report.completed ? "COMPLETE" : "PARTIAL RESULTS").eyebrow()
                        Text(report.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                }
            }
            if let report = store.diagnosticReport {
                Text("Coverage: \(report.scope)").font(.system(size: 11)).foregroundStyle(Theme.dim)
            }
            if let notice = store.exportNotice { Text(notice).font(.system(size: 12)).foregroundStyle(Theme.cyan) }
            let review = store.diagnosticFindings.filter { $0.status == .attention }
            if !review.isEmpty {
                Text("REVIEW FIRST").eyebrow()
                ForEach(review) { finding in DiagnosticCard(finding: finding) }
            }
            ForEach(DiagnosticCategory.allCases, id: \.self) { category in
                let items = store.diagnosticFindings.filter { $0.category == category }
                if !items.isEmpty {
                    Label(category.rawValue.uppercased(), systemImage: category.symbol).eyebrow()
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(items) { finding in DiagnosticCard(finding: finding) }
                    }
                }
            }
        }
    }

    private func metric(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(count)").font(.system(size: 29, weight: .light, design: .rounded)).foregroundStyle(color)
            Text(label).eyebrow()
        }
    }

    private func choose(applications: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = applications ? [.applicationBundle] : [.json, .propertyList, .png, .jpeg, .gif]
        panel.message = applications ? "Select up to 10 local apps. Lucius reads metadata and checks signatures; it never launches them." : "Select up to 20 local files, at most 4 MiB each. JSON/plist syntax and image headers are checked. No files are changed."
        panel.prompt = applications ? "Inspect" : "Check"
        panel.begin { response in
            if response == .OK { store.inspectSelected(panel.urls, applications: applications) }
        }
    }

    private func exportReport() {
        guard let report = store.diagnosticReport else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Lucius-diagnostics.md"
        panel.message = "Review before sharing: reports can include volume, app and file names. Nothing is uploaded."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try report.markdown.write(to: url, atomically: true, encoding: .utf8)
                store.exportNotice = "Report saved to \(url.lastPathComponent)."
            } catch { store.exportNotice = "Report could not be saved: \(error.localizedDescription)" }
        }
    }
}

struct DiagnosticCard: View {
    let finding: DiagnosticFinding
    private var color: Color {
        switch finding.status {
        case .attention: Theme.amber
        case .observed: Theme.cyan
        case .information, .unavailable: Theme.dim
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(finding.title).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                Spacer(minLength: 8)
                Text(finding.status.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            }
            Text(finding.value).font(.system(size: 20, weight: .light)).foregroundStyle(color).textSelection(.enabled)
            Text(finding.explanation).font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
