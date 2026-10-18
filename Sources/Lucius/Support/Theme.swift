import SwiftUI
import LuciusCore

enum Theme {
    static let background = Color(red: 0.025, green: 0.041, blue: 0.061)
    static let surface = Color(red: 0.045, green: 0.070, blue: 0.097)
    static let line = Color(red: 0.14, green: 0.23, blue: 0.30)
    static let cyan = Color(red: 0.50, green: 0.85, blue: 0.96)
    static let dim = Color(red: 0.48, green: 0.59, blue: 0.66)
    static let amber = Color(red: 0.96, green: 0.71, blue: 0.36)
    static let text = Color(red: 0.87, green: 0.93, blue: 0.96)
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
        background(Theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line.opacity(0.6), lineWidth: 1))
    }
}

struct ActionButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(primary ? Theme.background : Theme.text)
            .background(primary ? Theme.cyan.opacity(configuration.isPressed ? 0.7 : 1) : Theme.line.opacity(configuration.isPressed ? 0.7 : 0.35), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

func cpuText(_ cpu: Double?) -> String { cpu.map { String(format: "%.1f%%", $0) } ?? "—" }
func memoryText(_ bytes: UInt64?) -> String { bytes.map { String(format: "%.0f MB", Double($0) / 1_048_576) } ?? "—" }
