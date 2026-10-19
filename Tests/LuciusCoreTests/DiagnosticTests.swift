import XCTest
import Foundation
import Darwin
@testable import LuciusCore

private actor FindingCollector {
    var values: [DiagnosticFinding] = []
    func append(_ findings: [DiagnosticFinding]) { values += findings }
}

final class DiagnosticTests: XCTestCase {
    func testUnknownPressureAndInvalidCapacityStayUnknown() {
        XCTAssertEqual(DiagnosticRules.pressure(nil).0, .unavailable)
        XCTAssertEqual(DiagnosticRules.pressure(0).0, .unavailable)
        XCTAssertEqual(DiagnosticRules.pressure(2).0, .attention)
        XCTAssertEqual(DiagnosticRules.pressure(4).0, .attention)
        XCTAssertEqual(DiagnosticRules.storageStatus(available: 2, total: 0), .unavailable)
        XCTAssertEqual(DiagnosticRules.storageStatus(available: 101, total: 100), .unavailable)
        XCTAssertEqual(DiagnosticRules.storageStatus(available: -1, total: 100), .unavailable)
        XCTAssertEqual(DiagnosticRules.storageStatus(available: 9, total: 100), .attention)
        XCTAssertEqual(DiagnosticRules.storageStatus(available: 10, total: 100), .observed)
    }

    func testCommandTimeoutReapsOwnedChild() async throws {
        let result = try await DiagnosticCommand.run("/bin/sh", ["-c", "echo $$; exec /bin/sleep 20"], seconds: 0.1)
        XCTAssertTrue(result.interrupted)
        let pid = try XCTUnwrap(Int32(result.text))
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testCommandOutputLimitDoesNotDeadlock() async throws {
        let result = try await DiagnosticCommand.run("/usr/bin/head", ["-c", "1048576", "/dev/zero"], seconds: 2, outputLimit: 1024)
        XCTAssertTrue(result.interrupted)
        XCTAssertEqual(result.output.count, 1024)
    }

    func testTimeoutAlsoStopsOwnedDescendants() async throws {
        let result = try await DiagnosticCommand.run("/bin/sh", ["-c", "echo $$; /bin/sleep 20 & wait"], seconds: 0.1)
        XCTAssertTrue(result.interrupted)
        let group = try XCTUnwrap(Int32(result.text))
        for _ in 0..<50 {
            if kill(-group, 0) == -1 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(kill(-group, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testCancellationReapsOwnedChild() async throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: pidFile) }
        let task = Task {
            try await DiagnosticCommand.run("/bin/sh", ["-c", "echo $$ > \"$1\"; exec /bin/sleep 20", "fixture", pidFile.path], seconds: 5)
        }
        for _ in 0..<50 {
            if FileManager.default.fileExists(atPath: pidFile.path) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        let pid = try XCTUnwrap(Int32(String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testSelectedFilesAreBoundedAndNeverModified() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let valid = folder.appendingPathComponent("valid.json")
        let invalid = folder.appendingPathComponent("invalid.json")
        let large = folder.appendingPathComponent("large.json")
        let link = folder.appendingPathComponent("link.json")
        let original = Data("{\"value\": 123}".utf8)
        try original.write(to: valid)
        try Data("{broken".utf8).write(to: invalid)
        try Data(repeating: 32, count: 4_194_305).write(to: large)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: valid)
        XCTAssertEqual(SelectedDiagnostics.validateFile(valid).status, .observed)
        XCTAssertEqual(SelectedDiagnostics.validateFile(invalid).status, .attention)
        XCTAssertEqual(SelectedDiagnostics.validateFile(large).status, .unavailable)
        XCTAssertEqual(SelectedDiagnostics.validateFile(link).status, .unavailable)
        XCTAssertEqual(SelectedDiagnostics.validateFile(folder.appendingPathComponent("missing.json")).status, .unavailable)
        XCTAssertEqual(try Data(contentsOf: valid), original)
    }

    func testReportPreservesPartialAndUnknownResults() throws {
        let report = DiagnosticReport(startedAt: Date(), completedAt: Date(), scope: "Fixture", completed: false,
                                      findings: [.init(.power, "Battery", .unavailable, "Unknown", "Not exposed")])
        let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: JSONEncoder().encode(report))
        XCTAssertFalse(decoded.completed)
        XCTAssertEqual(decoded.unavailableCount, 1)
        XCTAssertEqual(decoded.reviewCount, 0)
        XCTAssertTrue(decoded.markdown.contains("partial results"))
        XCTAssertTrue(decoded.markdown.contains("Unavailable"))
    }

    func testLiveReadOnlyChecksReportEveryRequestedCategory() async throws {
        let collector = FindingCollector()
        try await SystemDiagnostics.run(categories: DiagnosticCategory.systemChecks) { _, findings in
            await collector.append(findings)
        }
        let findings = await collector.values
        XCTAssertEqual(Set(findings.map(\.category)), Set(DiagnosticCategory.systemChecks))
        XCTAssertTrue(findings.allSatisfy { !$0.value.isEmpty && !$0.explanation.isEmpty })
        for finding in findings { print("Diagnostic smoke: \(finding.title) | \(finding.status.rawValue) | \(finding.value)") }
    }
}
