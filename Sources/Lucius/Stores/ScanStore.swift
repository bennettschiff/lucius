import Foundation
import Observation
import LuciusCore

struct Incident: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let title: String
    var detail: String
}

enum WorkspaceSection: String, CaseIterable {
    case scan = "Component scan", diagnostics = "System overview", hardware = "Hardware tests", history = "History", about = "About Lucius"
    var symbol: String {
        switch self { case .scan: "viewfinder"; case .diagnostics: "waveform.path.ecg"; case .hardware: "cpu"; case .history: "clock.arrow.circlepath"; case .about: "info.circle" }
    }
}

@MainActor @Observable
final class ScanStore {
    var section: WorkspaceSection = .scan
    var symptom = ""
    var selectedID = "notifications"
    var results: [ComponentResult] = []
    var activeComponentIDs: Set<String> = []
    var isScanning = false
    var isRecovering = false
    var isDiagnosing = false
    var isTesting = false
    var selectedTests = Set(HardwareTest.allCases)
    var hardwareResults: [HardwareTestResult] = []
    var hardwareReports: [HardwareReport] = []
    var hardwarePhase = "Choose a bounded test to inspect your hardware"
    var hardwareProgress = 0.0
    var diagnosticFindings: [DiagnosticFinding] = []
    var diagnosticReport: DiagnosticReport?
    var diagnosticPhase = "Choose the checks you need"
    var diagnosticProgress = 0.0
    var selectedChecks: Set<DiagnosticCategory> = Set(DiagnosticCategory.systemChecks)
    var exportNotice: String?
    var progress = 0.0
    var phase = "Ready when you need it"
    var scanComplete = false
    var lastScanAt: Date?
    var errorMessage: String?
    var recoveryMessage: String?
    var awaitingConfirmation = false
    var confirmRestart = false
    var pendingIdentity: ProcessIdentity?
    var incidents: [Incident] = []
    var persistenceNotice: String?
    private var task: Task<Void, Never>?
    private var recoveryIncidentID: UUID?
    private let historyURL: URL
    private let hardwareURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        historyURL = base.appendingPathComponent("Lucius/incidents.json")
        hardwareURL = base.appendingPathComponent("Lucius/hardware-reports.json")
        if let data = try? Data(contentsOf: hardwareURL), data.count <= 2_000_000,
           let saved = try? JSONDecoder().decode([HardwareReport].self, from: data) {
            hardwareReports = Array(saved.prefix(10))
        }
        if let data = try? Data(contentsOf: historyURL), let saved = try? JSONDecoder().decode([Incident].self, from: data) {
            incidents = Array(saved.prefix(40))
        }
    }

    var isBusy: Bool { isScanning || isRecovering || isDiagnosing || isTesting }
    var selectedComponent: Component { Component.catalog.first { $0.id == selectedID } ?? Component.catalog[0] }
    var selectedResult: ComponentResult? { results.first { $0.id == selectedID } }
    var elevatedCount: Int { results.filter { $0.observation == .elevated }.count }
    var measuredCount: Int { results.filter { $0.averageCPU != nil }.count }
    var coverageText: String { "\(measuredCount) of \(results.count) measured" }
    var resultHeadline: String {
        if isScanning { return "Scanning beneath the surface" }
        if isRecovering { return "Verifying the restart" }
        if !scanComplete && !results.isEmpty { return "Scan stopped · partial results" }
        if scanComplete && measuredCount == 0 { return "No measurements available" }
        if scanComplete { return elevatedCount > 0 ? "Something deserves a closer look" : "No clear issue found" }
        return "See beneath the surface."
    }

    func startScan(deep: Bool = false) {
        guard !isBusy else { return }
        isScanning = true
        scanComplete = false
        errorMessage = nil
        recoveryMessage = nil
        awaitingConfirmation = false
        progress = 0
        results = []
        section = .scan
        let components = deep ? [selectedComponent] : Component.ordered(for: symptom)
        activeComponentIDs = Set(components.map(\.id))
        if !deep { selectedID = components[0].id }
        phase = deep ? "Taking a longer look at \(selectedComponent.name)…" : "Identifying your components…"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await Scanner.scan(components: components, intervals: deep ? 12 : 6) { [weak self] update in
                    await self?.receive(update)
                }
                try Task.checkCancellation()
                results = outcome
                scanComplete = true
                lastScanAt = Date()
                phase = "\(outcome.count) components checked · \(coverageText) · no changes made"
                if let elevated = outcome.first(where: { $0.observation == .elevated }) { selectedID = elevated.id }
                record(title: deep ? "Deeper check completed" : "System scan completed",
                       detail: "\(coverageText). \(elevatedCount) sustained high-CPU finding(s). UI responsiveness was not proven.")
            } catch is CancellationError {
                phase = "Scan cancelled · any displayed measurements are incomplete"
            } catch {
                errorMessage = error.localizedDescription
                phase = "Scan could not finish"
            }
            isScanning = false
            task = nil
        }
    }

    private func receive(_ update: ScanUpdate) {
        guard isScanning else { return }
        results = update.results
        progress = Double(update.completedIntervals) / Double(update.totalIntervals)
        phase = "Measurement \(update.completedIntervals) of \(update.totalIntervals) · checking activity over time"
    }

    func cancel() { task?.cancel() }
    func shutdown() async {
        let running = task
        running?.cancel()
        await running?.value
    }

    func startDiagnostics() {
        let checks = DiagnosticCategory.systemChecks.filter { selectedChecks.contains($0) }
        guard !checks.isEmpty else { return }
        runDiagnostics(scope: checks.map(\.rawValue).joined(separator: ", ")) { update in
            try await SystemDiagnostics.run(categories: checks) { category, findings in
                await update(category.rawValue, findings, Double((checks.firstIndex(of: category) ?? 0) + 1) / Double(checks.count))
            }
        }
    }

    func inspectSelected(_ urls: [URL], applications: Bool) {
        guard !urls.isEmpty else { return }
        let selected = Array(urls.prefix(applications ? 10 : 20))
        runDiagnostics(scope: "\(selected.count) selected \(applications ? "applications" : "files")") { update in
            if applications {
                try await SelectedDiagnostics.applications(selected) { findings in
                    await update("Checking selected applications", findings, 0)
                }
            } else {
                try await SelectedDiagnostics.files(selected) { findings in
                    await update("Checking selected files", findings, 0)
                }
            }
        }
    }

    private func runDiagnostics(scope: String, operation: @escaping @Sendable (
        @escaping @Sendable (String, [DiagnosticFinding], Double) async -> Void
    ) async throws -> Void) {
        guard !isBusy else { return }
        section = .diagnostics
        isDiagnosing = true
        diagnosticFindings = []
        diagnosticReport = nil
        diagnosticProgress = 0
        diagnosticPhase = "Collecting observations…"
        exportNotice = nil
        let started = Date()
        task = Task { [weak self] in
            guard let self else { return }
            var completed = false
            do {
                try await operation { [weak self] phase, findings, progress in
                    await self?.receiveDiagnostics(phase, findings, progress)
                }
                try Task.checkCancellation()
                completed = true
                diagnosticProgress = 1
                diagnosticPhase = "Checks complete · no changes made"
            } catch is CancellationError {
                diagnosticPhase = "Stopped · partial observations"
            } catch {
                diagnosticPhase = "Check stopped · \(error.localizedDescription)"
            }
            let report = DiagnosticReport(startedAt: started, completedAt: Date(), scope: scope,
                                          completed: completed, findings: diagnosticFindings)
            diagnosticReport = report
            record(title: completed ? "Diagnostics completed" : "Diagnostics stopped",
                   detail: "\(scope). \(report.findings.count) observations; \(report.reviewCount) to review; \(report.unavailableCount) unavailable. No repairs performed.")
            isDiagnosing = false
            task = nil
        }
    }

    private func receiveDiagnostics(_ phase: String, _ findings: [DiagnosticFinding], _ progress: Double) {
        diagnosticFindings.append(contentsOf: findings)
        diagnosticPhase = phase
        diagnosticProgress = progress
    }

    func startHardwareTests() {
        guard !isBusy else { return }
        let tests = HardwareTest.allCases.filter { selectedTests.contains($0) }
        guard !tests.isEmpty else { return }
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/LuciusDiagnosticWorker")
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("LuciusDiagnosticWorker")
        let worker = Bundle.main.bundleURL.pathExtension == "app" ? bundled : sibling
        guard FileManager.default.isExecutableFile(atPath: worker.path) else {
            hardwarePhase = "Diagnostic worker missing. Rebuild the complete app bundle."; return
        }
        section = .hardware; isTesting = true; hardwareResults = []; hardwareProgress = 0
        task = Task { [weak self] in
            guard let self else { return }
            for (index, test) in tests.enumerated() {
                do {
                    try Task.checkCancellation()
                    let result = try await HardwareRunner.run(test, worker: worker) { [weak self] event in
                        await self?.receiveHardware(event, index: index, total: tests.count)
                    }
                    hardwareResults.append(result)
                } catch {
                    hardwareResults.append(.init(test: test, outcome: error is CancellationError ? .stopped : .unavailable,
                        summary: error is CancellationError ? "Cancelled. The test worker has exited." : error.localizedDescription,
                        nextStep: "Run again when ready; incomplete tests have no pass result."))
                    break
                }
            }
            // Preserve explicit not-run results so a partial run cannot look complete.
            for test in tests where !hardwareResults.contains(where: { $0.test == test }) {
                hardwareResults.append(.init(test: test, outcome: .stopped, summary: "Not started because the run was cancelled.", nextStep: "Select this test to run it separately."))
            }
            hardwarePhase = Task.isCancelled ? "Stopped · completed results preserved" : "Run finished · review coverage and results below"
            let report = HardwareReport(requested: tests, results: hardwareResults)
            hardwareReports.insert(report, at: 0); hardwareReports = Array(hardwareReports.prefix(10))
            do {
                try FileManager.default.createDirectory(at: hardwareURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(hardwareReports).write(to: hardwareURL, options: .atomic)
            } catch { persistenceNotice = "Hardware report could not be saved: \(error.localizedDescription)" }
            record(title: "Hardware test run", detail: hardwareResults.map { "\($0.test.title): \($0.outcome.rawValue)" }.joined(separator: "; "))
            isTesting = false; task = nil
        }
    }

    private func receiveHardware(_ event: HardwareProgress, index: Int, total: Int) {
        hardwarePhase = event.phase
        hardwareProgress = (Double(index) + event.fraction) / Double(total)
    }

    func requestRestart() {
        guard !isBusy, selectedComponent.canRestart, let identity = selectedResult?.identity else { return }
        pendingIdentity = identity
        confirmRestart = true
    }

    func restart() {
        guard !isBusy, let expected = pendingIdentity else { return }
        pendingIdentity = nil
        isRecovering = true
        errorMessage = nil
        recoveryMessage = nil
        awaitingConfirmation = false
        phase = "Requesting a normal restart of Notification Center…"
        record(title: "Notification Center restart requested", detail: "User initiated a targeted restart. Verification pending.")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let recovered = try await Recovery.restart(expected: expected)
                let cpu = recovered.averageCPU.map { String(format: "%.1f%%", $0) } ?? "unavailable"
                recoveryMessage = "New process verified (PID \(recovered.replacement.pid)). CPU during the one-second recheck: \(cpu). Did the stuck banner clear?"
                phase = "Process restarted · visible recovery needs your confirmation"
                awaitingConfirmation = true
                let incident = record(title: "Notification Center restarted", detail: "Replacement PID \(recovered.replacement.pid). Recheck CPU: \(cpu). Symptom resolution unconfirmed.")
                recoveryIncidentID = incident
                // Old process measurements must not remain actionable after a repair.
                results.removeAll { $0.id == "notifications" }
                scanComplete = false
            } catch is CancellationError {
                recoveryMessage = "Verification stopped. A restart may already have been requested; run a fresh scan to inspect the current state."
                record(title: "Restart verification stopped", detail: "Current process and symptom status are unknown.")
            } catch {
                errorMessage = error.localizedDescription
                phase = "Restart could not be verified"
                record(title: "Restart not verified", detail: error.localizedDescription)
            }
            isRecovering = false
            task = nil
        }
    }

    func confirmRecovery(_ resolved: Bool) {
        awaitingConfirmation = false
        recoveryMessage = resolved ? "You confirmed the banner cleared. Recovery recorded." : "The process restarted, but your symptom remains. Try a deeper check or investigate the source app."
        if let index = incidents.firstIndex(where: { $0.id == recoveryIncidentID }) {
            incidents[index].detail += resolved ? " User confirmed the symptom cleared." : " User reported the symptom remains."
            saveHistory()
        }
    }

    @discardableResult private func record(title: String, detail: String) -> UUID {
        let incident = Incident(date: Date(), title: title, detail: detail)
        incidents.insert(incident, at: 0)
        incidents = Array(incidents.prefix(40))
        saveHistory()
        return incident.id
    }

    private func saveHistory() {
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(incidents).write(to: historyURL, options: .atomic)
        } catch { persistenceNotice = "History could not be saved: \(error.localizedDescription)" }
    }
}
