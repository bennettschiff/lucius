import Foundation

public enum HardwareTest: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu, memory, gpu, cooling
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cpu: "CPU calculation test"
        case .memory: "RAM pattern test"
        case .gpu: "GPU compute test"
        case .cooling: "Cooling & sensor observation"
        }
    }
    public var symbol: String {
        switch self { case .cpu: "cpu"; case .memory: "memorychip"; case .gpu: "square.stack.3d.up"; case .cooling: "fan" }
    }
    public var method: String {
        switch self {
        case .cpu: "Runs an up-to-two-second workload checking integer checksums and exact floating-point calculations against known answers across up to four concurrent workers."
        case .memory: "Writes and reads 64 MiB using six patterns: zeroes, ones, alternating bits, and two address-derived patterns. Stops if memory pressure rises."
        case .gpu: "Runs four Metal compute passes and compares every output against a CPU reference. Exercises 8 MiB of allocated GPU buffers."
        case .cooling: "Samples available temperatures, fan RPM and macOS thermal state for ten seconds. Shows ranges and changes; never changes fan speed."
        }
    }
    public var limit: String {
        switch self {
        case .cpu: "20-second limit · brief CPU load"
        case .memory: "20-second limit · 64 MiB allocation"
        case .gpu: "20-second limit · brief GPU load"
        case .cooling: "10-second observation · read-only"
        }
    }
    public var coverage: String {
        switch self {
        case .cpu: "A sample of CPU operations, not every instruction, cache or physical core. macOS chooses scheduling."
        case .memory: "Only this process's allocation is tested. Virtual memory and caches prevent certification of all physical RAM."
        case .gpu: "Only the selected Metal device and allocated buffers. Does not test display pixels, all GPU memory, video codecs or every execution unit."
        case .cooling: "Sensor access is model-dependent and undocumented. No calibrated fault thresholds or active fan-control test are claimed."
        }
    }
}

public enum HardwareOutcome: String, Codable, Sendable {
    case passed = "Passed", failed = "Failed", observed = "Observed"
    case unavailable = "Unavailable", stopped = "Stopped"
}

public struct HardwareMetric: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let value: String
    public init(_ name: String, _ value: String) { self.name = name; self.value = value }
}

public struct SensorSample: Codable, Sendable {
    public let elapsed: Double
    public let thermal: String
    public let temperatures: [String: Double]
    public let fanRPM: [String: Double]
}

public struct HardwareTestResult: Identifiable, Codable, Sendable {
    public var id: HardwareTest { test }
    public let test: HardwareTest
    public let outcome: HardwareOutcome
    public let summary: String
    public let elapsed: Double
    public let metrics: [HardwareMetric]
    public let samples: [SensorSample]
    public let nextStep: String
    public init(test: HardwareTest, outcome: HardwareOutcome, summary: String, elapsed: Double = 0,
                metrics: [HardwareMetric] = [], samples: [SensorSample] = [], nextStep: String) {
        self.test = test; self.outcome = outcome; self.summary = summary; self.elapsed = elapsed
        self.metrics = metrics; self.samples = samples; self.nextStep = nextStep
    }
}

public struct HardwareProgress: Codable, Sendable {
    public let test: HardwareTest
    public let fraction: Double
    public let phase: String
    public let result: HardwareTestResult?
    public init(_ test: HardwareTest, _ fraction: Double, _ phase: String, result: HardwareTestResult? = nil) {
        self.test = test; self.fraction = fraction; self.phase = phase; self.result = result
    }
}

public struct HardwareReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let model: String?
    public let operatingSystem: String?
    public let requested: [HardwareTest]
    public let results: [HardwareTestResult]
    public var markdown: String {
        let sections = results.map { result in
            let metrics = result.metrics.map { "- \($0.name): \($0.value)" }.joined(separator: "\n")
            let samples = result.samples.map { sample in
                let temps = sample.temperatures.sorted { $0.key < $1.key }.map { "\($0.key)=\(String(format: "%.1f", $0.value)) °C" }.joined(separator: ", ")
                let fans = sample.fanRPM.sorted { $0.key < $1.key }.map { "\($0.key)=\(Int($0.value)) RPM" }.joined(separator: ", ")
                return "- \(String(format: "%.1f", sample.elapsed)) s: \(sample.thermal); \(temps); \(fans)"
            }.joined(separator: "\n")
            return "## \(result.test.title) — \(result.outcome.rawValue)\n\n\(result.summary)\n\nDuration: \(String(format: "%.2f", result.elapsed)) s\n\n\(metrics)\n\nCoverage: \(result.test.coverage)\n\nNext step: \(result.nextStep)\n\n\(samples)"
        }
        return "# Lucius hardware tests\n\n\(date.formatted(.iso8601))\n\nMac: \(model ?? "Not recorded")\nOS: \(operatingSystem ?? "Not recorded")\n\nRequested: \(requested.map(\.title).joined(separator: ", "))\n\nA pass applies only to the completed workload. No disk repair or fan-control writes were performed.\n\n" + sections.joined(separator: "\n\n") + "\n"
    }
    public init(requested: [HardwareTest], results: [HardwareTestResult]) {
        self.id = UUID(); self.date = Date(); self.requested = requested; self.results = results
        self.model = HardwareEngine.model; self.operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
    }
}
