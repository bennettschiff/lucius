import Foundation

public enum CheckupPlan: String, CaseIterable, Codable, Sendable, Identifiable {
    case quick, extended
    public var id: String { rawValue }
    public var title: String { self == .quick ? "Quick checkup" : "Extended checkup" }
    public var subtitle: String {
        self == .quick ? "Start here for a slow or unresponsive Mac." : "A wider overview, plus brief hardware workloads."
    }
    public var coverage: String {
        self == .quick ? "Six interface components, memory pressure, thermal state, storage and power. Read-only."
        : "All quick checks, network interfaces, security settings, hardware inventory, CPU, RAM, GPU and cooling tests."
    }
    public var steps: [CheckupStep] {
        [.components] + (self == .quick ? [.resources, .storage, .power] : DiagnosticCategory.systemChecks).map(CheckupStep.system)
        + (self == .extended ? HardwareTest.allCases.map(CheckupStep.hardware) : [])
    }
}

public enum CheckupStep: Hashable, Codable, Sendable, Identifiable {
    case components, system(DiagnosticCategory), hardware(HardwareTest)
    public var id: String {
        switch self { case .components: "components"; case .system(let c): "system-\(c.rawValue)"; case .hardware(let t): "test-\(t.rawValue)" }
    }
    public var title: String {
        switch self { case .components: "Interface components"; case .system(let c): c.rawValue; case .hardware(let t): t.title }
    }
    public var symbol: String {
        switch self { case .components: "viewfinder"; case .system(let c): c.symbol; case .hardware(let t): t.symbol }
    }
}

public enum CheckupStepState: String, Codable, Sendable {
    case finished = "Finished", unavailable = "Unavailable", stopped = "Stopped", notStarted = "Not started"
}

public struct CheckupStepResult: Identifiable, Codable, Sendable {
    public var id: String { step.id }
    public let step: CheckupStep
    public let state: CheckupStepState
    public let findings: [DiagnosticFinding]
    public let hardware: HardwareTestResult?
    public let detail: String
    public var summary: String {
        if let hardware { return hardware.outcome.rawValue }
        guard state == .finished else { return state.rawValue }
        let review = findings.filter { $0.status == .attention }.count
        let unavailable = findings.filter { $0.status == .unavailable }.count
        if review > 0 { return "\(review) to review" }
        if unavailable > 0 { return "\(unavailable) unavailable" }
        return state.rawValue
    }
    public init(step: CheckupStep, state: CheckupStepState = .finished, findings: [DiagnosticFinding] = [],
                hardware: HardwareTestResult? = nil, detail: String = "") {
        self.step = step; self.state = state; self.findings = findings; self.hardware = hardware; self.detail = detail
    }
}

public struct CheckupReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let plan: CheckupPlan
    public let startedAt: Date
    public let completedAt: Date
    public let results: [CheckupStepResult]
    public let hardwareReport: HardwareReport?
    public var completed: Bool { results.count == plan.steps.count && !results.contains { $0.state == .stopped || $0.state == .notStarted } }
    public var findings: [DiagnosticFinding] { results.flatMap(\.findings) }
    public var reviewCount: Int { findings.filter { $0.status == .attention }.count + results.filter { $0.hardware?.outcome == .failed }.count }
    public var unavailableCount: Int {
        findings.filter { $0.status == .unavailable }.count + results.filter { $0.state == .unavailable }.count
    }
    public var headline: String {
        if !completed { return "Checkup stopped · partial results" }
        if reviewCount > 0 { return "\(reviewCount) finding\(reviewCount == 1 ? "" : "s") to review" }
        let assessed = findings.contains { $0.status == .observed } || results.contains {
            $0.hardware?.outcome == .passed || $0.hardware?.outcome == .observed
        }
        if !assessed { return "No assessments available" }
        return unavailableCount > 0 ? "No issues flagged in available checks" : "No issues flagged in these checks"
    }
    public init(plan: CheckupPlan, startedAt: Date, results: [CheckupStepResult]) {
        id = UUID(); self.plan = plan; self.startedAt = startedAt; completedAt = Date(); self.results = results
        let hardware = results.compactMap(\.hardware)
        hardwareReport = hardware.isEmpty ? nil : HardwareReport(requested: plan.steps.compactMap {
            if case .hardware(let test) = $0 { return test }; return nil
        }, results: hardware)
    }
    public var markdown: String {
        let sections = results.map { result in
            var text = "## \(result.step.title) · \(result.state.rawValue)\n\n\(result.detail)\n\n"
            text += result.findings.map { "### \($0.title) · \($0.status.rawValue)\n\n\($0.value)\n\n\($0.explanation)\n\nObserved: \($0.checkedAt.formatted(.iso8601))" }.joined(separator: "\n\n")
            if let hardware = result.hardware { text += "\n\n\(hardware.outcome.rawValue): \(hardware.summary)" }
            return text
        }
        return "# Lucius \(plan.title)\n\nStarted: \(startedAt.formatted(.iso8601))\nFinished: \(completedAt.formatted(.iso8601))\n\n\(headline) · \(unavailableCount) unavailable\n\n\(plan.coverage)\n\nNo repairs performed. Observations and sampled workloads do not certify the whole Mac.\n\n" + sections.joined(separator: "\n\n") + (hardwareReport.map { "\n\n" + $0.markdown } ?? "")
    }
}

public struct CheckupProgress: Sendable {
    public let index: Int
    public let fraction: Double
    public let phase: String
    public let result: CheckupStepResult?
}

/// One sequential owner; cancellation returns only after the current utility/worker has cleaned up.
public enum CheckupRunner {
    public typealias StepProgress = @Sendable (Double, String) async -> Void
    public typealias Execute = @Sendable (CheckupStep, URL, @escaping StepProgress) async throws -> CheckupStepResult

    public static func run(_ plan: CheckupPlan, worker: URL,
                           execute: Execute? = nil,
                           onUpdate: @escaping @Sendable (CheckupProgress) async -> Void) async -> CheckupReport {
        let execute = execute ?? executeStep
        let started = Date()
        var results: [CheckupStepResult] = []
        for (index, step) in plan.steps.enumerated() {
            if Task.isCancelled {
                results.append(.init(step: step, state: .notStarted, detail: "Not started after cancellation."))
                continue
            }
            await onUpdate(.init(index: index, fraction: 0, phase: "Checking \(step.title)…", result: nil))
            let result: CheckupStepResult
            do {
                result = try await execute(step, worker) { fraction, phase in
                    await onUpdate(.init(index: index, fraction: fraction, phase: phase, result: nil))
                }
            } catch is CancellationError {
                result = .init(step: step, state: .stopped, detail: "Stopped. This step did not complete; earlier results are preserved.")
            } catch {
                result = .init(step: step, state: .unavailable, detail: error.localizedDescription)
            }
            results.append(result)
            await onUpdate(.init(index: index, fraction: 1, phase: "\(step.title) · \(result.state.rawValue)", result: result))
            // CancellationError also stops injected executors that do not set Task cancellation.
            if result.state == .stopped || Task.isCancelled {
                results += plan.steps.dropFirst(index + 1).map { .init(step: $0, state: .notStarted, detail: "Not started after the run stopped.") }
                break
            }
        }
        return CheckupReport(plan: plan, startedAt: started, results: results)
    }

    private static func executeStep(_ step: CheckupStep, worker: URL, progress: @escaping StepProgress) async throws -> CheckupStepResult {
        switch step {
        case .components:
            let results = try await Scanner.scan(components: Component.catalog) { update in
                await progress(Double(update.completedIntervals) / Double(update.totalIntervals), "Sampling components · \(update.completedIntervals) of \(update.totalIntervals)")
            }
            return .init(step: step, findings: results.map { result in
                let status: DiagnosticStatus = switch result.observation {
                case .elevated: .attention
                case .observed: .observed
                case .notObserved, .changed, .ambiguous, .unavailable: .unavailable
                }
                let cpu = result.averageCPU.map { String(format: " · %.1f%% CPU", $0) } ?? ""
                return .init(.components, result.component.name, status, result.observation.rawValue + cpu, result.explanation)
            })
        case .system(let category):
            let collector = CheckupFindings()
            try await SystemDiagnostics.run(categories: [category]) { _, findings in await collector.append(findings) }
            return .init(step: step, findings: await collector.values)
        case .hardware(let test):
            let result = try await HardwareRunner.run(test, worker: worker) { event in await progress(event.fraction, event.phase) }
            let state: CheckupStepState = switch result.outcome {
            case .unavailable: .unavailable
            case .stopped: .stopped
            default: .finished
            }
            return .init(step: step, state: state, hardware: result)
        }
    }
}

private actor CheckupFindings {
    var values: [DiagnosticFinding] = []
    func append(_ findings: [DiagnosticFinding]) { values += findings }
}
