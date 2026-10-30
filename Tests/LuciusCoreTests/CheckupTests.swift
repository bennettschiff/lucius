import XCTest
@testable import LuciusCore

private actor StepRecorder {
    var steps: [CheckupStep] = []
    func append(_ step: CheckupStep) { steps.append(step) }
}

final class CheckupTests: XCTestCase, @unchecked Sendable {
    private let unusedWorker = URL(fileURLWithPath: "/unused-fixture-worker")

    func testQuickPlanNeverStartsHardwareAndRunsInOrder() async {
        let recorder = StepRecorder()
        let report = await CheckupRunner.run(.quick, worker: unusedWorker, execute: { step, _, _ in
            await recorder.append(step)
            return .init(step: step)
        }, onUpdate: { _ in })
        let steps = await recorder.steps
        XCTAssertEqual(steps, [.components, .system(.resources), .system(.storage), .system(.power)])
        XCTAssertTrue(report.completed)
        XCTAssertNil(report.hardwareReport)
    }

    func testExtendedPlanIncludesEverySystemAndHardwareCheckOnce() async {
        let report = await CheckupRunner.run(.extended, worker: unusedWorker, execute: { step, _, _ in
            .init(step: step)
        }, onUpdate: { _ in })
        XCTAssertEqual(report.results.map(\.step), [.components] + DiagnosticCategory.systemChecks.map(CheckupStep.system) + HardwareTest.allCases.map(CheckupStep.hardware))
        XCTAssertEqual(Set(report.results.map(\.id)).count, report.results.count)
    }

    func testStoppedStepPreservesEarlierFindingsAndDoesNotRunLaterStages() async {
        let recorder = StepRecorder()
        let report = await CheckupRunner.run(.quick, worker: unusedWorker, execute: { step, _, _ in
            await recorder.append(step)
            if step == .system(.resources) { throw CancellationError() }
            return .init(step: step, findings: [.init(.components, "Fixture", .attention, "Elevated", "Recorded before stop")])
        }, onUpdate: { _ in })
        let steps = await recorder.steps
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(report.results.map(\.state), [.finished, .stopped, .notStarted, .notStarted])
        XCTAssertEqual(report.reviewCount, 1)
        XCTAssertFalse(report.completed)
        XCTAssertTrue(report.markdown.contains("partial results"))
        XCTAssertTrue(report.markdown.contains("Not started"))
    }

    func testUnavailableStageDoesNotPreventIndependentChecks() async {
        struct FixtureFailure: Error {}
        let report = await CheckupRunner.run(.quick, worker: unusedWorker, execute: { step, _, _ in
            if step == .system(.resources) { throw FixtureFailure() }
            return .init(step: step, findings: [.init(.power, "Fixture", .observed, "Available", "Fixture")])
        }, onUpdate: { _ in })
        XCTAssertTrue(report.completed)
        XCTAssertEqual(report.unavailableCount, 1)
        XCTAssertEqual(report.results.last?.state, .finished)
        XCTAssertEqual(report.headline, "No issues flagged in available checks")
    }

    func testEntirelyUnavailableRunDoesNotLookHealthy() async {
        let report = await CheckupRunner.run(.quick, worker: unusedWorker, execute: { step, _, _ in
            .init(step: step, state: .unavailable, detail: "Fixture inaccessible")
        }, onUpdate: { _ in })
        XCTAssertEqual(report.headline, "No assessments available")
        XCTAssertEqual(report.unavailableCount, 4)
        XCTAssertTrue(report.completed)
    }

    func testActualTaskCancellationWaitsForExecutorCleanup() async throws {
        let recorder = StepRecorder()
        let task = Task {
            await CheckupRunner.run(.quick, worker: unusedWorker, execute: { step, _, _ in
                await recorder.append(step)
                try await Task.sleep(for: .seconds(5))
                return .init(step: step)
            }, onUpdate: { _ in })
        }
        for _ in 0..<100 {
            if !(await recorder.steps).isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()
        let report = await task.value
        XCTAssertFalse(report.completed)
        XCTAssertEqual(report.results.first?.state, .stopped)
        let steps = await recorder.steps
        XCTAssertEqual(steps.count, 1)
    }

    func testReportRoundTripPreservesHardwareOutcomeAndExportDate() async throws {
        let report = await CheckupRunner.run(.extended, worker: unusedWorker, execute: { step, _, _ in
            if case .hardware(let test) = step {
                return .init(step: step, hardware: .init(test: test, outcome: test == .cpu ? .failed : .passed,
                                                       summary: "Fixture result", nextStep: "Fixture follow-up"))
            }
            return .init(step: step, findings: [.init(.power, "Unknown sensor", .unavailable, "Unknown", "Fixture")])
        }, onUpdate: { _ in })
        let restored = try JSONDecoder().decode(CheckupReport.self, from: JSONEncoder().encode(report))
        XCTAssertEqual(restored.reviewCount, 1)
        XCTAssertEqual(restored.unavailableCount, 7)
        XCTAssertEqual(restored.hardwareReport?.date, report.hardwareReport?.date)
        XCTAssertEqual(restored.markdown, report.markdown)
        XCTAssertTrue(restored.markdown.contains("Failed"))
        XCTAssertTrue(restored.markdown.contains("Fixture follow-up"))
    }
}
