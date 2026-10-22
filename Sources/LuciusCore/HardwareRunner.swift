import Foundation

actor HardwareEventReader {
    let test: HardwareTest
    var pending = Data()
    var final: HardwareTestResult?
    var invalid = false
    init(_ test: HardwareTest) { self.test = test }
    func consume(_ data: Data, update: @Sendable (HardwareProgress) async -> Void) async {
        pending.append(data)
        guard pending.count <= 131_072 else { invalid = true; pending.removeAll(); return }
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline)
            pending.removeSubrange(...newline)
            guard let event = try? JSONDecoder().decode(HardwareProgress.self, from: line),
                  event.test == test, event.fraction.isFinite, (0...1).contains(event.fraction),
                  event.result == nil || event.result?.test == test, final == nil else { invalid = true; continue }
            if let result = event.result { final = result }
            await update(event)
        }
    }
    func result() -> HardwareTestResult? { !invalid && pending.isEmpty ? final : nil }
}

public enum HardwareRunner {
    public static func run(_ test: HardwareTest, worker: URL,
                           update: @escaping @Sendable (HardwareProgress) async -> Void) async throws -> HardwareTestResult {
        let reader = HardwareEventReader(test)
        let result = try await DiagnosticCommand.run(worker.path, [test.rawValue], seconds: 20, outputLimit: 131_072) { data in
            await reader.consume(data, update: update)
        }
        if result.succeeded, let final = await reader.result() { return final }
        return .init(test: test, outcome: result.interrupted ? .stopped : .unavailable,
                     summary: result.interrupted ? "The worker exceeded its time or output limit and was stopped." : "The worker did not return a complete, valid result (exit \(result.exitCode)).",
                     nextStep: "Retry after closing busy apps. An incomplete run does not establish a hardware fault.")
    }
}
