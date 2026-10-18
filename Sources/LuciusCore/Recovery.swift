import Foundation

public struct RecoveryResult: Sendable {
    public let replacement: ProcessIdentity
    public let averageCPU: Double?
}

public enum Recovery {
    public static func restart(expected: ProcessIdentity) async throws -> RecoveryResult {
        try Task.checkCancellation()
        try ProcessReader.terminateNotificationCenter(expected: expected)
        let component = Component.catalog[0]
        // At most ten seconds waiting for launchd to replace this user's process.
        for _ in 0..<20 {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(500))
            let matches = ProcessReader.matching(component, in: try ProcessReader.all())
            if matches.count == 1, let first = matches.first, first.identity != expected {
                try await Task.sleep(for: .seconds(1))
                let second = try ProcessReader.read(pid: first.identity.pid)
                guard second.identity == first.identity else { throw ProcessFailure.changed }
                return RecoveryResult(replacement: second.identity, averageCPU: second.cpu(since: first))
            }
        }
        throw RecoveryFailure.noReplacement
    }
}

public enum RecoveryFailure: Error, LocalizedError {
    case noReplacement
    public var errorDescription: String? {
        "The termination request was sent, but no verified replacement appeared within 10 seconds. Lucius did not escalate. Open Notification Center, then scan again."
    }
}
