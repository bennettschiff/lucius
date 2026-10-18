import XCTest
import Foundation
import Darwin
@testable import LuciusCore

final class ScannerTests: XCTestCase {
    private func sample(cpu: UInt64, time: Double, pid: Int32 = 123, start: UInt64 = 10, metrics: Bool = true) -> ProcessSnapshot {
        .init(identity: .init(pid: pid, uid: getuid(), path: "/fixture", startSeconds: start, startMicroseconds: 0),
              cpuNanoseconds: cpu, footprint: 1024, timestamp: time, metricsAvailable: metrics)
    }

    func test_cpuMeasuresOneCoreAndAllowsMultipleCores() {
        let first = sample(cpu: 1_000_000_000, time: 1)
        XCTAssertTrue(sample(cpu: 2_000_000_000, time: 2).cpu(since: first) == 100)
        XCTAssertTrue(sample(cpu: 5_000_000_000, time: 3).cpu(since: first) == 200)
    }

    func test_replacementsAndInvalidCountersCannotProduceCPU() {
        let first = sample(cpu: 1_000_000_000, time: 1)
        XCTAssertTrue(sample(cpu: 2_000_000_000, time: 2, start: 20).cpu(since: first) == nil)
        XCTAssertTrue(sample(cpu: 1, time: 2).cpu(since: first) == nil)
        XCTAssertTrue(sample(cpu: 2_000_000_000, time: 1).cpu(since: first) == nil)
        XCTAssertTrue(sample(cpu: 2_000_000_000, time: 2, metrics: false).cpu(since: first) == nil)
    }

    func test_oneSpikeDoesNotBecomeAFinding() {
        XCTAssertTrue(Scanner.assessment(samples: [0, 100, 0], count: 1, metrics: true, changed: false) == .observed)
        XCTAssertTrue(Scanner.assessment(samples: [75, 90, 99], count: 1, metrics: true, changed: false) == .elevated)
        XCTAssertTrue(Scanner.assessment(samples: [99, 99], count: 1, metrics: true, changed: false) == .observed)
    }

    func test_missingAndChangedProcessesAreNotHealthy() {
        XCTAssertTrue(Scanner.assessment(samples: [], count: 0, metrics: false, changed: false) == .notObserved)
        XCTAssertTrue(Scanner.assessment(samples: [0], count: 2, metrics: true, changed: false) == .ambiguous)
        XCTAssertTrue(Scanner.assessment(samples: [0], count: 1, metrics: false, changed: false) == .unavailable)
        XCTAssertTrue(Scanner.assessment(samples: [0], count: 1, metrics: true, changed: true) == .changed)
    }

    func test_symptomPrioritizationIsStableAndPreservesCoverage() {
        XCTAssertTrue(Component.ordered(for: "A notification is stuck")[0].id == "notifications")
        XCTAssertTrue(Component.ordered(for: "Previews won't open")[0].id == "preview")
        XCTAssertTrue(Component.ordered(for: "unknown symptom") == Component.catalog)
        XCTAssertTrue(Set(Component.ordered(for: "dock frozen").map(\.id)) == Set(Component.catalog.map(\.id)))
    }

    func test_nameOnlyImpostorCannotMatchCatalog() {
        let fake = ProcessSnapshot(identity: .init(pid: 123, uid: getuid(), path: "/tmp/NotificationCenter", startSeconds: 1, startMicroseconds: 0),
                                   cpuNanoseconds: 0, footprint: 0, timestamp: 0, metricsAvailable: true)
        XCTAssertTrue(ProcessReader.matching(Component.catalog[0], in: [fake]).isEmpty)
        XCTAssertThrowsError(try ProcessReader.terminateNotificationCenter(expected: fake.identity))
    }

    func test_cancellationStopsAReadOnlyScan() async throws {
        let work = Task {
            try await Scanner.scan(components: [Component.catalog[0]]) { _ in }
        }
        work.cancel()
        do { _ = try await work.value; XCTFail("Cancelled scan should throw") }
        catch is CancellationError { }
    }
}
