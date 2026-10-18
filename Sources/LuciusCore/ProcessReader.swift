import Foundation
import CProcess
import Darwin

public struct ProcessIdentity: Hashable, Sendable {
    public let pid: Int32
    public let uid: UInt32
    public let path: String
    public let startSeconds: UInt64
    public let startMicroseconds: UInt64
}

public struct ProcessSnapshot: Sendable {
    public let identity: ProcessIdentity
    public let cpuNanoseconds: UInt64
    public let footprint: UInt64
    public let timestamp: Double
    public let metricsAvailable: Bool

    public func cpu(since previous: Self) -> Double? {
        guard metricsAvailable, previous.metricsAvailable, identity == previous.identity,
              timestamp > previous.timestamp, cpuNanoseconds >= previous.cpuNanoseconds else { return nil }
        return Double(cpuNanoseconds - previous.cpuNanoseconds) / 1e9 / (timestamp - previous.timestamp) * 100
    }
}

public enum ProcessFailure: Error, LocalizedError, Sendable {
    case access(Int32)
    case changed
    case unsupported
    case ambiguous
    public var errorDescription: String? {
        switch self {
        case .access(let code): "macOS did not allow this operation (\(code): \(String(cString: strerror(code))))."
        case .changed: "The process changed since the scan. Run a fresh scan before trying again."
        case .unsupported: "This component has no verified restart action in this version."
        case .ambiguous: "Lucius could not identify exactly one matching process. Nothing was restarted."
        }
    }
}

public enum ProcessReader {
    public static func read(pid: Int32) throws -> ProcessSnapshot {
        var raw = LCProcess()
        let error = lc_read_process(pid, &raw)
        guard error == 0 else { throw ProcessFailure.access(Int32(error)) }
        return snapshot(raw)
    }

    public static func all() throws -> [ProcessSnapshot] {
        var pids = [Int32](repeating: 0, count: 16_384)
        let count = lc_list_user_pids(&pids, Int32(pids.count))
        guard count >= 0 else { throw ProcessFailure.access(-count) }
        let snapshots = pids.prefix(Int(count)).filter { $0 > 0 }.compactMap { try? read(pid: $0) }
        guard !snapshots.isEmpty else { throw ProcessFailure.access(EACCES) }
        return snapshots
    }

    public static func matching(_ component: Component, in snapshots: [ProcessSnapshot]) -> [ProcessSnapshot] {
        snapshots.filter { $0.identity.uid == getuid() && component.paths.contains($0.identity.path) }
    }

    public static func terminateNotificationCenter(expected: ProcessIdentity) throws {
        guard let component = Component.catalog.first(where: { $0.id == "notifications" }),
              component.paths.contains(expected.path), expected.uid == getuid() else { throw ProcessFailure.unsupported }
        let matches = matching(component, in: try all())
        guard matches.count == 1 else { throw ProcessFailure.ambiguous }
        guard matches[0].identity == expected else { throw ProcessFailure.changed }
        var fresh = LCProcess()
        let readError = lc_read_process(expected.pid, &fresh)
        guard readError == 0 else { throw ProcessFailure.access(Int32(readError)) }
        guard snapshot(fresh).identity == expected else { throw ProcessFailure.changed }
        let error = lc_terminate_verified(&fresh)
        guard error == 0 else { throw ProcessFailure.access(Int32(error)) }
    }

    private static func snapshot(_ raw: LCProcess) -> ProcessSnapshot {
        var value = raw
        let path = withUnsafePointer(to: &value.path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        return .init(identity: .init(pid: raw.pid, uid: raw.uid, path: path,
                                    startSeconds: raw.start_sec, startMicroseconds: raw.start_usec),
                     cpuNanoseconds: raw.cpu_ns, footprint: raw.footprint, timestamp: raw.timestamp,
                     metricsAvailable: raw.metrics_available != 0)
    }
}
