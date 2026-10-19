import Foundation
import Darwin
import IOKit.ps
import Metal

public enum SystemDiagnostics {
    public static func run(categories: [DiagnosticCategory],
                           onUpdate: @Sendable (DiagnosticCategory, [DiagnosticFinding]) async -> Void) async throws {
        for category in DiagnosticCategory.systemChecks where categories.contains(category) {
            try Task.checkCancellation()
            let findings: [DiagnosticFinding]
            switch category {
            case .resources: findings = resources()
            case .storage: findings = storage()
            case .power: findings = await power()
            case .network: findings = network()
            case .security: findings = try await security()
            case .hardware: findings = hardware()
            default: findings = []
            }
            try Task.checkCancellation()
            await onUpdate(category, findings)
        }
    }

    private static func resources() -> [DiagnosticFinding] {
        var level: Int32 = 0
        var size = MemoryLayout.size(ofValue: level)
        let pressure = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 ? level : nil
        let state = DiagnosticRules.pressure(pressure)
        var swap = xsw_usage()
        size = MemoryLayout.size(ofValue: swap)
        let hasSwap = sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalLabel: String
        let thermalStatus: DiagnosticStatus
        switch thermal {
        case .nominal: thermalLabel = "Nominal"; thermalStatus = .observed
        case .fair: thermalLabel = "Fair"; thermalStatus = .information
        case .serious: thermalLabel = "Serious"; thermalStatus = .attention
        case .critical: thermalLabel = "Critical"; thermalStatus = .attention
        @unknown default: thermalLabel = "Unknown"; thermalStatus = .unavailable
        }
        return [
            .init(.resources, "Memory pressure", state.0, state.1,
                  "A point-in-time OS pressure reading. High pressure can affect responsiveness; this does not test RAM for hardware faults."),
            .init(.resources, "Installed memory", .information, byteLabel(Int64(ProcessInfo.processInfo.physicalMemory)),
                  "Physical memory available to this Mac. Memory use alone is not a diagnosis."),
            .init(.resources, "Swap in use", hasSwap ? .information : .unavailable, hasSwap ? byteLabel(Int64(swap.xsu_used)) : "Not available",
                  "Swap can remain allocated after earlier workloads. This snapshot cannot attribute swap to one app or establish current memory pressure."),
            .init(.resources, "Thermal state", thermalStatus, thermalLabel,
                  "macOS's overall thermal assessment, not a temperature measurement or a fan test.")
        ]
    }

    private static func storage() -> [DiagnosticFinding] {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsLocalKey]
        let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        var urls = [URL(fileURLWithPath: "/")]
        urls += mounts.filter { $0.path != "/" }
        var findings: [DiagnosticFinding] = []
        for url in urls.prefix(16) {
            guard let values = try? url.resourceValues(forKeys: keys) else {
                findings.append(.init(.storage, url.lastPathComponent.isEmpty ? "Startup volume" : url.lastPathComponent, .unavailable,
                                      "Capacity unavailable", "This volume could not be read.")); continue
            }
            guard values.volumeIsLocal == true else { continue }
            let name = url.path == "/" ? "Startup volume" : (values.volumeName ?? url.lastPathComponent)
            guard let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity else {
                findings.append(.init(.storage, name, .unavailable, "Capacity unavailable", "macOS did not provide capacity values.")); continue
            }
            let status = DiagnosticRules.storageStatus(available: Int64(free), total: Int64(total))
            findings.append(.init(.storage, name, status, "\(byteLabel(Int64(free))) available / \(byteLabel(Int64(total)))",
                                  "Below 10% available is flagged for review. APFS volumes may share container space; do not add their capacities. No disk integrity or repair test was performed."))
        }
        return findings.isEmpty ? [.init(.storage, "Local storage", .unavailable, "No capacity readings", "No supported local volumes were readable.")] : findings
    }

    private static func power() async -> [DiagnosticFinding] {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return [.init(.power, "Power sources", .unavailable, "Not available", "macOS did not return power-source information.")]
        }
        var findings: [DiagnosticFinding] = []
        for source in sources.prefix(8) {
            guard let details = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            let name = details[kIOPSNameKey] as? String ?? "Power source"
            let current = details[kIOPSCurrentCapacityKey] as? Int
            let maximum = details[kIOPSMaxCapacityKey] as? Int
            let percent: String
            if let current, let maximum, maximum > 0, current >= 0, current <= maximum {
                percent = String(format: "%.0f%% charged", Double(current) / Double(maximum) * 100)
            } else { percent = "Charge unavailable" }
            let state = details[kIOPSPowerSourceStateKey] as? String ?? "Power state unavailable"
            findings.append(.init(.power, name, .information, "\(percent) · \(state)",
                                  "OS-reported battery or UPS charge. Charge percentage is not battery health or remaining lifespan."))
        }
        if sources.isEmpty {
            findings.append(.init(.power, "Battery / UPS", .information, "No battery or UPS reported", "This can be normal on a desktop Mac or for an unsupported UPS."))
        }
        if !sources.isEmpty {
            do {
                let result = try await DiagnosticCommand.run("/usr/sbin/system_profiler", ["SPPowerDataType", "-json"], seconds: 6)
                if result.succeeded, let root = try JSONSerialization.jsonObject(with: result.output) as? [String: Any],
                   let entries = root["SPPowerDataType"] as? [[String: Any]] {
                    var found = false
                    for entry in entries {
                        guard let health = entry["sppower_battery_health_info"] as? [String: Any] else { continue }
                        found = true
                        let condition = health["sppower_battery_health"] as? String
                        let cycles = (health["sppower_battery_cycle_count"] as? NSNumber)?.stringValue ?? "Unavailable"
                        let capacity = health["sppower_battery_health_maximum_capacity"] as? String ?? "Unavailable"
                        let status: DiagnosticStatus = condition == nil ? .unavailable : (condition == "Good" || condition == "Normal" ? .observed : .attention)
                        findings.append(.init(.power, "Battery condition", status, condition ?? "Unavailable",
                                              "OS-reported condition. Cycle count: \(cycles). Maximum capacity: \(capacity). These are estimates, not a prediction of failure."))
                    }
                    if !found { findings.append(batteryUnavailable) }
                } else { findings.append(batteryUnavailable) }
            } catch { findings.append(batteryUnavailable) }
        }
        return findings
    }

    private static var batteryUnavailable: DiagnosticFinding {
        .init(.power, "Battery condition", .unavailable, "Health details unavailable", "macOS did not provide recognized health fields within the check's time budget. Basic charge information may still be available.")
    }

    private static func network() -> [DiagnosticFinding] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return [.init(.network, "Interfaces", .unavailable, "Not available", "Network interface enumeration failed.")]
        }
        defer { freeifaddrs(pointer) }
        var names: Set<String> = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            let value = item.pointee
            if let address = value.ifa_addr, (address.pointee.sa_family == AF_INET || address.pointee.sa_family == AF_INET6),
               value.ifa_flags & UInt32(IFF_UP) != 0, value.ifa_flags & UInt32(IFF_LOOPBACK) == 0 {
                names.insert(String(cString: value.ifa_name))
            }
            cursor = value.ifa_next
        }
        return [.init(.network, "Configured interfaces", names.isEmpty ? .attention : .observed,
                      names.isEmpty ? "No active addressed interface" : names.sorted().joined(separator: ", "),
                      "Interfaces marked up with an IP address, including virtual/VPN interfaces. This does not prove internet access, DNS, Wi-Fi signal quality or hardware health. No network requests were sent.")]
    }

    private static func security() async throws -> [DiagnosticFinding] {
        let checks: [(String, String, [String], String, String)] = [
            ("FileVault", "/usr/bin/fdesetup", ["status"], "FileVault is On.", "FileVault is Off."),
            ("System Integrity Protection", "/usr/bin/csrutil", ["status"], "System Integrity Protection status: enabled.", "System Integrity Protection status: disabled."),
            ("Gatekeeper assessments", "/usr/sbin/spctl", ["--status"], "assessments enabled", "assessments disabled")
        ]
        var findings: [DiagnosticFinding] = []
        for (name, executable, arguments, enabled, disabled) in checks {
            try Task.checkCancellation()
            do {
                let output = try await DiagnosticCommand.run(executable, arguments, seconds: 3)
                let status: DiagnosticStatus
                let value: String
                if output.succeeded && output.text == enabled { status = .observed; value = "Enabled" }
                else if !output.interrupted && output.text == disabled { status = .attention; value = "Disabled" }
                else { status = .unavailable; value = "Status could not be confirmed" }
                findings.append(.init(.security, name, status, value,
                                      "Read-only configuration check. \(status == .unavailable ? "Permissions, an OS change or a nonstandard state may limit this check. " : "")Review intentional exceptions in System Settings; Lucius does not change protections or scan for malware."))
            } catch is CancellationError { throw CancellationError() }
            catch { findings.append(.init(.security, name, .unavailable, "Check unavailable", "The system utility could not be run. No setting was changed.")) }
        }
        return findings
    }

    private static func hardware() -> [DiagnosticFinding] {
        let info = ProcessInfo.processInfo
        var findings: [DiagnosticFinding] = [
            .init(.hardware, "Operating system", .information, info.operatingSystemVersionString, "Reported by macOS. Compatibility of individual diagnostics can vary by OS release."),
            .init(.hardware, "Processor", .information, "\(info.activeProcessorCount) active / \(info.processorCount) logical cores", "Processor inventory only. No stress test, cache test or hardware fault certification was performed.")
        ]
        if let device = MTLCreateSystemDefaultDevice() {
            findings.append(.init(.hardware, "Graphics", .information, device.name,
                                  "\(device.hasUnifiedMemory ? "Shared CPU/GPU memory" : "Dedicated GPU memory"). Metal is available. No render, video-memory or display test was performed."))
        } else { findings.append(.init(.hardware, "Graphics", .unavailable, "No default Metal device", "Graphics capability could not be queried.")) }
        return findings
    }
}
