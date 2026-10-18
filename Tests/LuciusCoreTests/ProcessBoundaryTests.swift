import XCTest
import Foundation
import Darwin
import CProcess
@testable import LuciusCore

final class ProcessBoundaryTests: XCTestCase {
    func test_liveSelfIdentityAndMetrics() throws {
        let snapshot = try ProcessReader.read(pid: getpid())
        XCTAssertTrue(snapshot.identity.uid == getuid())
        XCTAssertTrue(snapshot.identity.pid == getpid())
        XCTAssertTrue(snapshot.identity.startSeconds > 0)
        XCTAssertTrue(snapshot.footprint > 0)
        XCTAssertTrue(snapshot.metricsAvailable)
    }

    func test_terminationRejectsWrongIdentityThenStopsOnlyOwnedFixture() async throws {
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/bin/sleep")
        fixture.arguments = ["20"] // Hard stop even if this test's cleanup fails.
        try fixture.run()
        defer {
            if fixture.isRunning { fixture.terminate() }
            fixture.waitUntilExit()
        }
        var original = LCProcess()
        XCTAssertTrue(lc_read_process(fixture.processIdentifier, &original) == 0)
        var wrongStart = original
        wrongStart.start_sec += 1
        XCTAssertTrue(lc_terminate_verified(&wrongStart) == ESTALE)
        XCTAssertTrue(fixture.isRunning)
        var wrongUser = original
        wrongUser.uid = getuid() + 1
        XCTAssertTrue(lc_terminate_verified(&wrongUser) == EPERM)
        XCTAssertTrue(fixture.isRunning)
        var wrongPath = original
        withUnsafeMutablePointer(to: &wrongPath.path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { pointer in
                pointer[0] = 88
            }
        }
        XCTAssertTrue(lc_terminate_verified(&wrongPath) == ESTALE)
        XCTAssertTrue(fixture.isRunning)
        XCTAssertTrue(lc_terminate_verified(&original) == 0)
        for _ in 0..<20 {
            if !fixture.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(!fixture.isRunning)
        XCTAssertTrue(lc_terminate_verified(&original) != 0)
    }
}
