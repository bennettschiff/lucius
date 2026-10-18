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
    case scan = "System scan", history = "History", about = "About Lucius"
    var symbol: String {
        switch self { case .scan: "viewfinder"; case .history: "clock.arrow.circlepath"; case .about: "info.circle" }
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

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        historyURL = base.appendingPathComponent("Lucius/incidents.json")
        if let data = try? Data(contentsOf: historyURL), let saved = try? JSONDecoder().decode([Incident].self, from: data) {
            incidents = Array(saved.prefix(40))
        }
    }

    var isBusy: Bool { isScanning || isRecovering }
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
