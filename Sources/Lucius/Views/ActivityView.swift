import SwiftUI
import LuciusCore

/// Shared motion policy: event-driven transitions, with no animation clock at idle.
struct ActivityMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("minimalMotion") private var minimalMotion = false
    let active: Bool
    func body(content: Content) -> some View {
        content.symbolEffect(.pulse, options: .repeating,
                             isActive: active && !reduceMotion && !minimalMotion && scenePhase == .active)
    }
}

struct RunProgress: View {
    let value: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("minimalMotion") private var minimalMotion = false
    var body: some View {
        ProgressView(value: min(1, max(0, value)))
            .tint(color)
            .animation(reduceMotion || minimalMotion ? nil : .easeInOut(duration: 0.25), value: value)
            .accessibilityLabel("Run progress")
    }
}

private struct ElapsedTime: View {
    let start: Date
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: scenePhase != .active)) { context in
            Text("\(max(0, Int(context.date.timeIntervalSince(start))))s elapsed")
                .monospacedDigit().foregroundStyle(Theme.dim)
        }
    }
}

struct ActivityStatusBar: View {
    let store: ScanStore
    private var title: String {
        if store.isCancelling { return "Stopping · waiting for cleanup…" }
        if store.isTesting { return store.hardwarePhase }
        if store.isDiagnosing { return store.diagnosticPhase }
        return store.phase
    }
    private var progress: Double? {
        if store.isTesting { return store.hardwareProgress }
        if store.isDiagnosing { return store.diagnosticHasProgress ? store.diagnosticProgress : nil }
        return store.isScanning ? store.progress : nil
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isCancelling ? "stop.circle" : "waveform.path.ecg")
                .foregroundStyle(Theme.cyan).modifier(ActivityMotion(active: !store.isCancelling))
            Text(title).lineLimit(1)
            Spacer(minLength: 8)
            if let start = store.activityStartedAt { ElapsedTime(start: start) }
            if let progress { RunProgress(value: progress, color: Theme.cyan).frame(width: 100) }
            Button("Stop") { store.cancel() }.disabled(store.isCancelling).buttonStyle(.borderless)
        }
        .font(.system(size: 12)).padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct HardwareRunPanel: View {
    let store: ScanStore
    let results: [HardwareTestResult]
    let requested: [HardwareTest]
    let reportDate: Date?
    private var active: HardwareTest? { store.isTesting ? store.activeHardwareTest : nil }
    private var accent: Color { active.map { Theme.color(for: $0) } ?? Theme.cyan }
    private var title: String {
        if store.isCancelling { return "Stopping tests…" }
        if let active { return active.title }
        if results.isEmpty { return "A closer look at your Mac." }
        return results.contains { $0.outcome == .stopped } ? "Run stopped" : "Your results are ready"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(accent.opacity(0.13), lineWidth: 5)
                    if store.isTesting {
                        Circle().trim(from: 0, to: min(1, max(0, store.hardwareTestProgress)))
                            .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: active?.symbol ?? "desktopcomputer")
                        .font(.system(size: 30, weight: .medium)).foregroundStyle(accent)
                        .modifier(ActivityMotion(active: store.isTesting && !store.isCancelling))
                }.frame(width: 76, height: 76).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.isTesting ? "TEST IN PROGRESS" : (reportDate.map { "SAVED RUN · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "HARDWARE AT A GLANCE")).eyebrow()
                    Text(title).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(store.isTesting ? store.hardwarePhase : (results.isEmpty
                         ? "Choose your tests below. Follow each step as it runs."
                         : "\(results.count) results recorded · review each outcome and its coverage below."))
                        .font(.system(size: 12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if store.isTesting, let start = store.activityStartedAt {
                    ElapsedTime(start: start).font(.system(size: 12))
                }
            }
            if store.isTesting {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Overall progress").foregroundStyle(Theme.dim)
                        Spacer()
                        Text("\(Int(store.hardwareProgress * 100))%").monospacedDigit()
                    }.font(.system(size: 11))
                    RunProgress(value: store.hardwareProgress, color: accent)
                }
            }
            HStack(spacing: 10) {
                ForEach(HardwareTest.allCases) { test in
                    stage(test)
                }
            }
        }.padding(24)
        .background(LinearGradient(colors: [accent.opacity(0.10), Theme.violet.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.18), lineWidth: 1))
    }

    private func stage(_ test: HardwareTest) -> some View {
        let result = results.first { $0.test == test }
        let selected = requested.contains(test)
        let running = active == test && result == nil
        let label = result?.outcome.rawValue ?? (running ? (store.isCancelling ? "Stopping" : "Running") : (selected ? (store.isTesting ? "Queued" : "Ready") : "Not selected"))
        let symbol: String = switch result?.outcome {
        case .passed: "checkmark.circle.fill"
        case .observed: "eye.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .stopped: "stop.circle"
        case .unavailable: "questionmark.circle"
        case nil: running ? test.symbol : "circle.dotted"
        }
        let color = result?.outcome == .failed || result?.outcome == .stopped ? Theme.amber : Theme.color(for: test)
        return HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(selected ? color : Theme.dim)
                .modifier(ActivityMotion(active: running && !store.isCancelling))
            VStack(alignment: .leading, spacing: 3) {
                Text(test == .memory ? "RAM" : test.rawValue.uppercased()).font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 11)).foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 0)
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface.opacity(running ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(running ? color.opacity(0.5) : .clear, lineWidth: 1))
            .accessibilityElement(children: .combine)
    }
}

struct DiagnosticsRunPanel: View {
    let store: ScanStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 28)).foregroundStyle(Theme.teal)
                    .modifier(ActivityMotion(active: !store.isCancelling))
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.isCancelling ? "Stopping checks…" : store.diagnosticPhase).font(.system(size: 16, weight: .semibold))
                    Text("\(store.diagnosticFindings.count) observations collected").font(.system(size: 12)).foregroundStyle(Theme.dim)
                }
                Spacer()
                if let start = store.activityStartedAt { ElapsedTime(start: start).font(.system(size: 12)) }
            }
            if store.diagnosticHasProgress { RunProgress(value: store.diagnosticProgress, color: Theme.teal) }
        }.padding(20).background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
