import Foundation
import LuciusCore

@main struct DiagnosticWorker {
    static func main() async {
        guard CommandLine.arguments.count == 2, let test = HardwareTest(rawValue: CommandLine.arguments[1]) else { exit(64) }
        let emit: @Sendable (HardwareProgress) -> Void = { event in
            guard let data = try? JSONEncoder().encode(event) else { return }
            FileHandle.standardOutput.write(data + Data([10]))
        }
        let result = await HardwareEngine.run(test, emit: emit)
        emit(.init(test, 1, result.summary, result: result))
    }
}
