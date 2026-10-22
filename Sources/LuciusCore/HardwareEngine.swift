import Foundation
import Darwin
import Metal
import CProcess

public enum HardwareEngine {
    public static var model: String {
        var bytes = [CChar](repeating: 0, count: 128)
        var size = bytes.count
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "Unknown Mac" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    public static func coolingDesign(model: String) -> String {
        // Verified M3 MacBook Air identifiers; unknown models never imply a fan.
        ["Mac15,12", "Mac15,13"].contains(model) ? "Fanless design · MacBook Air (M3)" : "Fan capability depends on accessible sensors"
    }
    static func pressure() -> Int32? {
        var value: Int32 = 0; var size = MemoryLayout<Int32>.size
        return sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0) == 0 ? value : nil
    }
    static func safetyReason() -> String? {
        safetyReason(thermal: ProcessInfo.processInfo.thermalState.rawValue, pressure: pressure())
    }
    static func safetyReason(thermal: Int, pressure: Int32?) -> String? {
        if thermal >= 2 { return "macOS reports serious or critical thermal pressure." }
        guard let pressure else { return "Memory pressure could not be read." }
        if pressure != 1 { return "macOS memory pressure is elevated." }
        return nil
    }
    static var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "Nominal"; case .fair: "Fair"; case .serious: "Serious"; case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
    public static func run(_ test: HardwareTest, emit: @escaping @Sendable (HardwareProgress) -> Void) async -> HardwareTestResult {
        let start = Date()
        emit(.init(test, 0, "Preparing \(test.title.lowercased())"))
        let result: HardwareTestResult
        if test != .cooling, let reason = safetyReason() {
            result = .init(test: test, outcome: .stopped, summary: reason, nextStep: "Let the Mac cool or close memory-heavy apps, then retry.")
        } else {
            switch test {
            case .cpu: result = await cpu(emit)
            case .memory: result = memory(emit)
            case .gpu: result = gpu(emit)
            case .cooling: result = await cooling(emit)
            }
        }
        return .init(test: test, outcome: result.outcome, summary: result.summary, elapsed: Date().timeIntervalSince(start), metrics: result.metrics, samples: result.samples, nextStep: result.nextStep)
    }
    // FNV-1a over bytes 0...255 repeated 256 times. Golden value is a fixed fixture,
    // not a second invocation of this implementation.
    static func integerAnswer() -> UInt64 { lc_cpu_integer_answer() }
    static func floatAnswer() -> Double { lc_cpu_float_answer() }
    static func cpu(_ emit: @escaping @Sendable (HardwareProgress) -> Void) async -> HardwareTestResult {
        let workers = min(4, ProcessInfo.processInfo.activeProcessorCount)
        let counts = await withTaskGroup(of: (Int, Int, Bool).self) { group in
            for _ in 0..<workers {
                group.addTask {
                    var checked = 0; var errors = 0
                    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                    for iteration in 0..<8192 {
                        if iteration >= 128 && ContinuousClock.now >= deadline { break }
                        if safetyReason() != nil || Task.isCancelled { return (checked, errors, true) }
                        if integerAnswer() != 2216012086724862757 { errors += 1 }
                        if floatAnswer() != 4195328 { errors += 1 }
                        checked += 2
                    }
                    return (checked, errors, false)
                }
            }
            var total = 0; var errors = 0; var stopped = false; var done = 0
            for await item in group {
                total += item.0; errors += item.1; stopped = stopped || item.2; done += 1
                emit(.init(.cpu, Double(done) / Double(workers), "\(total) known-answer checks completed"))
            }
            return (total, errors, stopped)
        }
        let status: HardwareOutcome = counts.1 > 0 ? .failed : (counts.2 ? .stopped : .passed)
        return .init(test: .cpu, outcome: status, summary: counts.2 ? "Workload stopped for resource pressure or cancellation." : "\(counts.0) known-answer checks; \(counts.1) mismatches.", metrics: [.init("Concurrent workers", "\(workers)"), .init("Completed checks", "\(counts.0)"), .init("Mismatches", "\(counts.1)")], nextStep: counts.1 > 0 ? "Repeat after cooling. Persistent mismatches warrant Apple Diagnostics and hardware service; software can also cause failures." : "If symptoms persist, run Apple Diagnostics for broader hardware coverage.")
    }
    static func memory(_ emit: @Sendable (HardwareProgress) -> Void) -> HardwareTestResult {
        let bytes = 64 * 1024 * 1024
        let count = UInt32(bytes / 8)
        guard let raw = malloc(bytes) else { return .init(test: .memory, outcome: .unavailable, summary: "Could not allocate 64 MiB.", nextStep: "Close memory-heavy apps and retry.") }
        defer { free(raw) }
        let pointer = raw.assumingMemoryBound(to: UInt64.self)
        let patterns: [(String, UInt64, Int32)] = [("Zeroes", 0, 0), ("Ones", .max, 0), ("Alternating A", 0xAAAAAAAAAAAAAAAA, 0), ("Alternating 5", 0x5555555555555555, 0), ("Address-derived", 0, 1), ("Inverted address-derived", .max, 1)]
        var mismatches: UInt64 = 0; var complete = 0; var firstFailure: UInt32?
        for (name, pattern, address) in patterns {
            if safetyReason() != nil || Task.isCancelled { break }
            lc_memory_fill(pointer, count, pattern, address)
            var first: UInt32 = 0
            let errors = lc_memory_check(pointer, count, pattern, address, &first)
            if errors > 0 && firstFailure == nil { firstFailure = first }
            mismatches += errors; complete += 1
            emit(.init(.memory, Double(complete) / 6, "\(name): checked 64 MiB"))
        }
        var metrics: [HardwareMetric] = [.init("Allocation", "64 MiB"), .init("Patterns completed", "\(complete) / 6"), .init("Total data compared", "\(complete * 64) MiB"), .init("Mismatched words", "\(mismatches)")]
        if let firstFailure { metrics.append(.init("First mismatch byte offset", "\(UInt64(firstFailure) * 8)")) }
        return .init(test: .memory, outcome: mismatches > 0 ? .failed : (complete == 6 ? .passed : .stopped), summary: complete == 6 ? "Six write/read patterns completed in the allocated memory." : "Stopped before all patterns completed because resource pressure rose.", metrics: metrics, nextStep: mismatches > 0 ? "Save your work. Repeat and run Apple Diagnostics; a mismatch needs investigation." : "This bounded allocation cannot rule out faults elsewhere in physical RAM.")
    }
    static func gpuExpected(_ value: UInt32, pass: UInt32) -> UInt32 { (value &* 1664525 &+ 1013904223) ^ (pass &* 2654435761) }
    static func gpu(_ emit: @Sendable (HardwareProgress) -> Void) -> HardwareTestResult {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            return .init(test: .gpu, outcome: .unavailable, summary: "No accessible Metal device.", nextStep: "Check graphics support and run Apple Diagnostics.")
        }
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void verify(device const uint *a [[buffer(0)]], device uint *b [[buffer(1)]], constant uint &pass [[buffer(2)]], uint i [[thread_position_in_grid]]) {
            b[i] = (a[i] * 1664525u + 1013904223u) ^ (pass * 2654435761u);
        }
        """
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let function = library.makeFunction(name: "verify") else { throw CocoaError(.featureUnsupported) }
            let pipeline = try device.makeComputePipelineState(function: function)
            let count = 1_048_576
            guard let input = device.makeBuffer(length: count * 4, options: .storageModeShared), let output = device.makeBuffer(length: count * 4, options: .storageModeShared) else { throw CocoaError(.featureUnsupported) }
            let a = input.contents().bindMemory(to: UInt32.self, capacity: count)
            let b = output.contents().bindMemory(to: UInt32.self, capacity: count)
            for i in 0..<count { a[i] = UInt32(i) }
            var mismatches = 0; var complete = 0
            for pass in UInt32(0)..<4 {
                if safetyReason() != nil || Task.isCancelled { break }
                // Poison outputs so an unexecuted kernel cannot pass from stale data.
                for i in 0..<count { b[i] = ~gpuExpected(a[i], pass: pass) }
                guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else { throw CocoaError(.featureUnsupported) }
                encoder.setComputePipelineState(pipeline)
                encoder.setBuffer(input, offset: 0, index: 0); encoder.setBuffer(output, offset: 0, index: 1)
                var parameter = pass
                encoder.setBytes(&parameter, length: 4, index: 2)
                encoder.dispatchThreads(.init(width: count, height: 1, depth: 1), threadsPerThreadgroup: .init(width: min(256, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
                encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
                guard command.status == .completed else { throw command.error ?? CocoaError(.featureUnsupported) }
                for i in 0..<count { if b[i] != gpuExpected(a[i], pass: pass) { mismatches += 1 } }
                complete += 1
                emit(.init(.gpu, Double(complete) / 4, "Metal pass \(complete) / 4 verified"))
            }
            return .init(test: .gpu, outcome: mismatches > 0 ? .failed : (complete == 4 ? .passed : .stopped), summary: "\(complete * count) GPU outputs compared with CPU reference.", metrics: [.init("Device", device.name), .init("Buffers", "8 MiB total"), .init("Passes completed", "\(complete) / 4"), .init("Mismatches", "\(mismatches)")], nextStep: mismatches > 0 ? "Repeat and run Apple Diagnostics. A mismatch can arise from hardware, driver or software faults." : "Use Apple Diagnostics for broader coverage; this does not certify all GPU hardware.")
        } catch {
            return .init(test: .gpu, outcome: .unavailable, summary: "Metal workload could not complete: \(error.localizedDescription)", nextStep: "Check macOS updates and Apple Diagnostics. An execution error alone does not establish a hardware fault.")
        }
    }
    static func cooling(_ emit: @Sendable (HardwareProgress) -> Void) async -> HardwareTestResult {
        var connection: UInt32 = 0
        let opened = lc_smc_open(&connection) == 0
        defer { if opened { lc_smc_close(connection) } }
        func read(_ key: String) -> Double? {
            var value = 0.0
            return opened && lc_smc_read(connection, key, &value) == 0 ? value : nil
        }
        let keys = ["TC0P", "TC0D", "Tp01", "Tp05", "Tp09", "Tp0D", "Te05", "Te0S", "Tg0f", "Tg0j", "TB0T"]
        let start = Date(); var samples: [SensorSample] = []
        let fanless = ["Mac15,12", "Mac15,13"].contains(model)
        let fans = read("FNum").flatMap { $0 >= 0 && $0 <= 8 ? Int($0) : nil }
        for index in 0...10 {
            if Task.isCancelled { break }
            var temps: [String: Double] = [:]; var rpm: [String: Double] = [:]
            for key in keys { if let value = read(key), value > 0 && value <= 125 { temps[key] = value } }
            for fan in 0..<(fans ?? 0) { if let value = read("F\(fan)Ac"), value >= 0 && value <= 20_000 { rpm["Fan \(fan + 1)"] = value } }
            samples.append(.init(elapsed: Date().timeIntervalSince(start), thermal: thermal, temperatures: temps, fanRPM: rpm))
            emit(.init(.cooling, Double(index) / 10, "Sensor sample \(index + 1) / 11 · \(thermal.lowercased())"))
            if index < 10 { try? await Task.sleep(for: .seconds(1)) }
        }
        let temps = samples.flatMap { $0.temperatures.values }; let rpms = samples.flatMap { $0.fanRPM.values }
        let range: ( [Double], String) -> String = { values, unit in
            guard let low = values.min(), let high = values.max() else { return "Unavailable" }
            return String(format: "%.1f–%.1f %@", low, high, unit)
        }
        return .init(test: .cooling, outcome: .observed, summary: coolingDesign(model: model), metrics: [.init("Mac model", model), .init("Temperature range (all sampled keys)", range(temps, "°C")), .init("Fan RPM range", fanless ? "Not applicable · fanless Mac" : range(rpms, "RPM")), .init(fanless ? "Fan design" : "SMC fan count", fanless ? "No fans (model specification)" : (fans.map(String.init) ?? "Unavailable")), .init("Thermal states", Set(samples.map(\.thermal)).sorted().joined(separator: ", "))], samples: samples, nextStep: "Raw sensor keys are shown without inferred component labels. Fan control is not supported. If heat or noise persists, check ventilation and run Apple Diagnostics.")
    }
}
