import SwiftUI
import LuciusCore

enum Theme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let line = Color.primary.opacity(0.13)
    static let cyan = Color.blue
    static let dim = Color.secondary
    static let amber = Color.orange
    static let text = Color.primary
    static let violet = Color.purple
    static let teal = Color.teal
    static let green = Color.green

    static func color(for test: HardwareTest) -> Color {
        switch test { case .cpu: cyan; case .memory: violet; case .gpu: teal; case .cooling: amber }
    }

    static func color(for section: WorkspaceSection) -> Color {
        switch section { case .scan: cyan; case .diagnostics: teal; case .hardware: violet; case .history: amber; case .about: cyan }
    }
    static func color(for observation: ComponentObservation?) -> Color {
        switch observation {
        case .elevated: amber
        case .observed: cyan
        default: dim
        }
    }
}

extension View {
    func eyebrow() -> some View { font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.7).foregroundStyle(Theme.dim) }
    func panel() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

struct ActionButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(primary ? Color.white : Theme.text)
            .background(primary ? Theme.cyan.opacity(configuration.isPressed ? 0.7 : 1) : Theme.cyan.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

func cpuText(_ cpu: Double?) -> String { cpu.map { String(format: "%.1f%%", $0) } ?? "—" }
func memoryText(_ bytes: UInt64?) -> String { bytes.map { String(format: "%.0f MB", Double($0) / 1_048_576) } ?? "—" }
