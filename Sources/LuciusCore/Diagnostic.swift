import Foundation

public enum DiagnosticStatus: String, Codable, Sendable {
    case observed = "Observed", attention = "Review", unavailable = "Unavailable", information = "Information"
}

public enum DiagnosticCategory: String, CaseIterable, Codable, Sendable {
    case components = "Interface components"
    case resources = "Memory & thermal", storage = "Storage", power = "Power", network = "Network"
    case security = "Security", hardware = "Hardware", applications = "Applications", files = "Files"
    public var symbol: String {
        switch self {
        case .components: "viewfinder"
        case .resources: "memorychip"
        case .storage: "internaldrive"
        case .power: "battery.100percent"
        case .network: "network"
        case .security: "lock.shield"
        case .hardware: "desktopcomputer"
        case .applications: "app.badge.checkmark"
        case .files: "doc.text.magnifyingglass"
        }
    }
    public static let systemChecks: [Self] = [.resources, .storage, .power, .network, .security, .hardware]
}

public struct DiagnosticFinding: Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: DiagnosticCategory
    public let title: String
    public let status: DiagnosticStatus
    public let value: String
    public let explanation: String
    public let checkedAt: Date
    public init(_ category: DiagnosticCategory, _ title: String, _ status: DiagnosticStatus,
                _ value: String, _ explanation: String) {
        id = UUID(); self.category = category; self.title = title; self.status = status
        self.value = value; self.explanation = explanation; checkedAt = Date()
    }
}

public struct DiagnosticReport: Codable, Sendable {
    public let startedAt: Date
    public let completedAt: Date
    public let scope: String
    public let completed: Bool
    public let findings: [DiagnosticFinding]
    public init(startedAt: Date, completedAt: Date, scope: String, completed: Bool, findings: [DiagnosticFinding]) {
        self.startedAt = startedAt; self.completedAt = completedAt; self.scope = scope
        self.completed = completed; self.findings = findings
    }
    public var reviewCount: Int { findings.filter { $0.status == .attention }.count }
    public var unavailableCount: Int { findings.filter { $0.status == .unavailable }.count }
    public var markdown: String {
        let lines = findings.map {
            "### \($0.category.rawValue): \($0.title)\n\n\($0.status.rawValue) · \($0.value)\n\n\($0.explanation)\n\nObserved: \($0.checkedAt.formatted(.iso8601))"
        }
        return "# Lucius diagnostic report\n\nScope: \(scope)\n\nStarted: \(startedAt.formatted(.iso8601))\n\nFinished: \(completedAt.formatted(.iso8601))\n\n\(completed ? "Completed" : "Stopped — partial results") · \(reviewCount) to review · \(unavailableCount) unavailable\n\nObservations are not a hardware certification. No repairs were performed. This export can contain device, volume, application and file names.\n\n" + lines.joined(separator: "\n\n") + "\n"
    }
}

enum DiagnosticRules {
    static func storageStatus(available: Int64, total: Int64) -> DiagnosticStatus {
        guard total > 0, available >= 0, available <= total else { return .unavailable }
        return Double(available) / Double(total) < 0.10 ? .attention : .observed
    }
    static func pressure(_ level: Int32?) -> (DiagnosticStatus, String) {
        switch level {
        case 1: (.observed, "Normal")
        case 2: (.attention, "Warning")
        case 4: (.attention, "Critical")
        default: (.unavailable, "Not exposed by macOS")
        }
    }
}

func byteLabel(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .memory)
}
