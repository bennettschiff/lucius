import Foundation
import Darwin
import CProcess

struct DiagnosticCommandResult: Sendable {
    let output: Data
    let exitCode: Int32
    let interrupted: Bool
    var text: String { String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    var succeeded: Bool { !interrupted && exitCode == 0 }
}

// Fixed commands are selected by adapters, never built from symptom text. Drain a
// nonblocking merged pipe so a verbose tool cannot deadlock on a full pipe.
enum DiagnosticCommand {
    static func run(_ executable: String, _ arguments: [String], seconds: Double = 5,
                    outputLimit: Int = 262_144, onOutput: (@Sendable (Data) async -> Void)? = nil) async throws -> DiagnosticCommandResult {
        try Task.checkCancellation()
        let pipe = Pipe()
        let fd = pipe.fileHandleForReading.fileDescriptor
        defer { try? pipe.fileHandleForReading.close(); try? pipe.fileHandleForWriting.close() }
        guard fcntl(fd, F_SETFL, O_NONBLOCK) != -1 else { throw CocoaError(.fileReadUnknown) }
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        defer { for argument in argv { free(argument) } }
        let pid = argv.withUnsafeBufferPointer {
            lc_spawn_diagnostic(executable, $0.baseAddress, pipe.fileHandleForWriting.fileDescriptor, fd)
        }
        guard pid > 0 else { throw POSIXError(POSIXErrorCode(rawValue: -pid) ?? .EIO) }
        try? pipe.fileHandleForWriting.close()
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        let deadline = ContinuousClock.now.advanced(by: .seconds(max(0.05, min(seconds, 30))))
        let limit = max(1, min(outputLimit, 1_048_576))
        var interrupted = false
        var status: Int32 = 0
        var reaped = false
        func drain() async {
            while data.count < limit {
                let count = Darwin.read(fd, &buffer, min(buffer.count, limit - data.count))
                if count <= 0 { break }
                let chunk = Data(buffer.prefix(count))
                data.append(chunk)
                await onOutput?(chunk)
            }
        }
        while !reaped {
            await drain()
            let waited = waitpid(pid, &status, WNOHANG)
            if waited == pid || (waited == -1 && errno == ECHILD) { reaped = true; break }
            if Task.isCancelled || ContinuousClock.now >= deadline || data.count >= limit {
                interrupted = true
                break
            }
            await pause()
        }
        // Helpers belong to this run too. Never leave a descendant behind when
        // the root command exits early or a check is stopped. Signal only the
        // dedicated group created atomically at spawn, never a name match.
        if kill(-pid, 0) == 0 {
            _ = kill(-pid, SIGTERM)
            let stopDeadline = ContinuousClock.now.advanced(by: .milliseconds(500))
            while kill(-pid, 0) == 0 && ContinuousClock.now < stopDeadline {
                if !reaped && waitpid(pid, &status, WNOHANG) == pid { reaped = true }
                await pause()
            }
            if kill(-pid, 0) == 0 { _ = kill(-pid, SIGKILL) }
        }
        if !reaped {
            while waitpid(pid, &status, 0) == -1 && errno == EINTR { }
        }
        await drain()
        if data.count >= limit { interrupted = true }
        try Task.checkCancellation()
        let signal = status & 0x7f
        return .init(output: data, exitCode: signal == 0 ? (status >> 8) & 0xff : -signal, interrupted: interrupted)
    }

    private static func pause() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(25)) { continuation.resume() }
        }
    }
}
