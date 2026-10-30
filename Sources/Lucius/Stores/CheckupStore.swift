import Foundation
import LuciusCore


extension ScanStore {
    var workerURL: URL {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/LuciusDiagnosticWorker")
        }
        return URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("LuciusDiagnosticWorker")
    }

    var activeSection: WorkspaceSection {
        if isCheckingUp { return .home }
        if isTesting { return .hardware }
        if isDiagnosing { return .diagnostics }
        return .scan
    }

    var displayedCheckup: CheckupReport? {
        checkupReports.first { $0.id == selectedCheckupID } ?? checkupReports.first
    }

    func startCheckup(_ plan: CheckupPlan) {
        guard !isBusy else { return }
        section = .home; checkupPlan = plan; isCheckingUp = true
        activityStartedAt = Date(); isCancelling = false
        selectedCheckupID = nil; checkupResults = []; checkupProgress = 0; checkupStepIndex = 0
        checkupPhase = "Preparing \(plan.title.lowercased())…"
        let worker = workerURL
        task = Task { [weak self] in
            guard let self else { return }
            let report = await CheckupRunner.run(plan, worker: worker) { [weak self] update in
                await self?.receiveCheckup(update, total: plan.steps.count)
            }
            checkupResults = report.results
            checkupReports.insert(report, at: 0)
            checkupReports = Array(checkupReports.prefix(10))
            saveReports(checkupReports, to: checkupURL)
            checkupPhase = report.headline
            record(title: plan.title, detail: "\(report.headline). \(report.unavailableCount) unavailable. Full report available in Checkup.")
            isCheckingUp = false; isCancelling = false; task = nil
        }
    }

    private func receiveCheckup(_ update: CheckupProgress, total: Int) {
        checkupStepIndex = update.index
        checkupPhase = update.phase
        checkupProgress = (Double(update.index) + min(1, max(0, update.fraction))) / Double(total)
        if let result = update.result { checkupResults.append(result) }
    }

    func showDiagnosticReport(_ report: DiagnosticReport) {
        guard !isDiagnosing else { return }
        diagnosticReport = report; diagnosticFindings = report.findings
        diagnosticPhase = "Saved overview · " + report.completedAt.formatted(date: .abbreviated, time: .shortened)
        exportNotice = nil; section = .diagnostics
    }

    static func loadReports<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 5_000_000,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func saveReports<T: Encodable>(_ reports: T, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(reports).write(to: url, options: .atomic)
        } catch { persistenceNotice = "Report could not be saved: \(error.localizedDescription)" }
    }
}
