import Foundation

public enum ComponentObservation: String, Codable, Sendable {
    case observed = "Observed"
    case elevated = "Elevated activity"
    case unavailable = "Metrics unavailable"
    case notObserved = "Not observed"
    case changed = "Process changed"
    case ambiguous = "Multiple matches"
}

public struct ComponentResult: Identifiable, Sendable {
    public var id: String { component.id }
    public let component: Component
    public let processes: [ProcessSnapshot]
    public let cpuSamples: [Double]
    public let observation: ComponentObservation
    public let checkedAt: Date
    public var averageCPU: Double? { cpuSamples.isEmpty ? nil : cpuSamples.reduce(0, +) / Double(cpuSamples.count) }
    public var footprint: UInt64? { processes.count == 1 && processes[0].metricsAvailable ? processes[0].footprint : nil }
    public var identity: ProcessIdentity? { processes.count == 1 ? processes[0].identity : nil }
    public var explanation: String {
        switch observation {
        case .observed: "No sustained high CPU was measured in this window. A running process may still have an unresponsive interface."
        case .elevated: "CPU remained elevated across several measurements. This may explain your symptom, but legitimate work can also cause it."
        case .unavailable: "The process was identified, but macOS did not provide enough resource measurements."
        case .notObserved: "No matching process was observed. It may be inactive, inaccessible, or use a different path on this macOS version."
        case .changed: "The process appeared, exited, or was replaced during the scan. A fresh check can establish a stable measurement."
        case .ambiguous: "More than one process matched. Lucius will not choose one to restart."
        }
    }
}

public struct ScanUpdate: Sendable {
    public let completedIntervals: Int
    public let totalIntervals: Int
    public let results: [ComponentResult]
}

public enum Scanner {
    public static func assessment(samples: [Double], count: Int, metrics: Bool, changed: Bool) -> ComponentObservation {
        if count == 0 { return .notObserved }
        if count > 1 { return .ambiguous }
        if changed { return .changed }
        if !metrics || samples.isEmpty { return .unavailable }
        // Require three consecutive elevated observations, not a single spike.
        if samples.count >= 3 && samples.suffix(3).allSatisfy({ $0 >= 70 }) { return .elevated }
        return .observed
    }

    public static func scan(
        components: [Component], intervals: Int = 6,
        onUpdate: @Sendable (ScanUpdate) async -> Void
    ) async throws -> [ComponentResult] {
        let total = min(max(intervals, 3), 12)
        var previous = try ProcessReader.all()
        var history: [String: [Double]] = [:]
        var changed = Set<String>()
        var results: [ComponentResult] = []
        for step in 1...total {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(1))
            let current = try ProcessReader.all()
            results = components.map { component in
                let old = ProcessReader.matching(component, in: previous)
                let new = ProcessReader.matching(component, in: current)
                if Set(old.map(\.identity)) != Set(new.map(\.identity)) { changed.insert(component.id) }
                if old.count == 1, new.count == 1, let cpu = new[0].cpu(since: old[0]) {
                    history[component.id, default: []].append(cpu)
                }
                let samples = history[component.id] ?? []
                return ComponentResult(component: component, processes: new, cpuSamples: samples,
                    observation: assessment(samples: samples, count: new.count,
                        metrics: new.first?.metricsAvailable == true, changed: changed.contains(component.id)), checkedAt: Date())
            }
            await onUpdate(.init(completedIntervals: step, totalIntervals: total, results: results))
            previous = current
        }
        return results
    }
}
