import XCTest
import CProcess
@testable import LuciusCore

final class HardwareTests: XCTestCase, @unchecked Sendable {
    func testPackagedWorkloadsOnHost() async throws {
        guard ProcessInfo.processInfo.environment["LUCIUS_HARDWARE_SMOKE"] == "1" else {
            throw XCTSkip("Opt in to bounded hardware workloads on the host")
        }
        let worker = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/debug/LuciusDiagnosticWorker")
        var results: [HardwareTestResult] = []
        for test in HardwareTest.allCases {
            let result = try await HardwareRunner.run(test, worker: worker) { _ in }
            print("Hardware smoke: \(test.rawValue) | \(result.outcome.rawValue) | \(result.summary) | \(result.metrics.map { $0.name + ": " + $0.value }.joined(separator: "; "))")
            XCTAssertEqual(result.outcome, test == .cooling ? .observed : .passed)
            results.append(result)
        }
        let report = HardwareReport(requested: HardwareTest.allCases, results: results)
        try FileManager.default.createDirectory(atPath: "artifacts", withIntermediateDirectories: true)
        try report.markdown.write(toFile: "artifacts/hardware-smoke.md", atomically: true, encoding: .utf8)
        let cancelled = Task { try await HardwareRunner.run(.cooling, worker: worker) { _ in } }
        try await Task.sleep(for: .milliseconds(150))
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Expected cancellation after worker cleanup") }
        catch is CancellationError { }
    }

    func testPressureAndThermalStopsAreConservative() {
        XCTAssertNil(HardwareEngine.safetyReason(thermal: 0, pressure: 1))
        XCTAssertNotNil(HardwareEngine.safetyReason(thermal: 2, pressure: 1))
        XCTAssertNotNil(HardwareEngine.safetyReason(thermal: 0, pressure: 2))
        XCTAssertNotNil(HardwareEngine.safetyReason(thermal: 0, pressure: nil))
    }

    func testCPUKnownAnswers() {
        XCTAssertEqual(HardwareEngine.integerAnswer(), 2216012086724862757)
        XCTAssertEqual(HardwareEngine.floatAnswer(), 4195328)
    }
    func testMemoryPatternsDetectCorruption() {
        let buffer = UnsafeMutablePointer<UInt64>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        for address: Int32 in [0, 1] {
            for pattern: UInt64 in [0, .max, 0xAAAAAAAAAAAAAAAA, 0x5555555555555555] {
                lc_memory_fill(buffer, 1024, pattern, address)
                var first: UInt32 = 0
                XCTAssertEqual(lc_memory_check(buffer, 1024, pattern, address, &first), 0)
                buffer[17] ^= 1; buffer[1000] ^= 1
                XCTAssertEqual(lc_memory_check(buffer, 1024, pattern, address, &first), 2)
                XCTAssertEqual(first, 17)
            }
        }
    }
    func testGPUReferenceFixtures() {
        XCTAssertEqual(HardwareEngine.gpuExpected(0, pass: 0), 1013904223)
        XCTAssertEqual(HardwareEngine.gpuExpected(1, pass: 0), 1015568748)
        XCTAssertEqual(HardwareEngine.gpuExpected(.max, pass: 0), 1012239698)
    }
    func testUnknownMacDoesNotInferFanlessDesign() {
        XCTAssertTrue(HardwareEngine.coolingDesign(model: "Mac15,13").contains("Fanless"))
        XCTAssertFalse(HardwareEngine.coolingDesign(model: "Unknown").contains("Fanless"))
    }
    func testWorkerProtocolHandlesSplitFramesAndRejectsTruncation() async throws {
        let reader = HardwareEventReader(.cpu)
        let final = HardwareTestResult(test: .cpu, outcome: .passed, summary: "Fixture", nextStep: "Fixture")
        let data = try JSONEncoder().encode(HardwareProgress(.cpu, 1, "Complete", result: final)) + Data([10])
        await reader.consume(data.prefix(10)) { _ in }
        let incomplete = await reader.result(); XCTAssertNil(incomplete)
        await reader.consume(data.dropFirst(10)) { _ in }
        let complete = await reader.result(); XCTAssertEqual(complete?.outcome, .passed)
        await reader.consume(Data("trailing partial frame".utf8)) { _ in }
        let truncated = await reader.result(); XCTAssertNil(truncated)
    }
    func testWorkerProtocolRejectsWrongTestAndDuplicateFinal() async throws {
        let reader = HardwareEventReader(.cpu)
        let data = try JSONEncoder().encode(HardwareProgress(.memory, 0.5, "Wrong test")) + Data([10])
        await reader.consume(data) { _ in }
        let final = HardwareTestResult(test: .cpu, outcome: .passed, summary: "Fixture", nextStep: "Fixture")
        let valid = try JSONEncoder().encode(HardwareProgress(.cpu, 1, "Done", result: final)) + Data([10])
        await reader.consume(valid) { _ in }
        let rejected = await reader.result(); XCTAssertNil(rejected)
        let duplicate = HardwareEventReader(.cpu)
        await duplicate.consume(valid + valid) { _ in }
        let duplicateResult = await duplicate.result(); XCTAssertNil(duplicateResult)
    }
    func testReportPreservesCoverageAndResults() throws {
        let report = HardwareReport(requested: [.memory, .gpu], results: [
            .init(test: .memory, outcome: .stopped, summary: "Cancelled", nextStep: "Retry"),
            .init(test: .gpu, outcome: .stopped, summary: "Not started", nextStep: "Retry")])
        let decoded = try JSONDecoder().decode(HardwareReport.self, from: JSONEncoder().encode(report))
        XCTAssertEqual(decoded.id, report.id)
        XCTAssertEqual(decoded.results.count, 2)
        XCTAssertTrue(decoded.markdown.contains("Not started"))
        XCTAssertTrue(decoded.markdown.contains("Virtual memory"))
    }
}
