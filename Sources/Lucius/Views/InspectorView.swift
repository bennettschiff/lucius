import SwiftUI
import LuciusCore

struct InspectorView: View {
    @Bindable var store: ScanStore
    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("IN FOCUS").eyebrow()
                    Spacer()
                    Image(systemName: "scope").foregroundStyle(Theme.dim)
                }
                Image(systemName: store.selectedComponent.symbol)
                    .font(.system(size: 25, weight: .ultraLight)).foregroundStyle(Theme.cyan).padding(.top, 4)
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.selectedComponent.name).font(.system(size: 20, weight: .light))
                    Text(store.selectedComponent.category).eyebrow()
                }
                Text(store.selectedComponent.purpose).font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Theme.line).frame(height: 1)
                if let result = store.selectedResult {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(result.observation.rawValue).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.color(for: result.observation))
                        HStack {
                            metric("CPU · ONE CORE", value: cpuText(result.averageCPU))
                            Spacer()
                            metric("FOOTPRINT", value: memoryText(result.footprint))
                        }
                        if !result.cpuSamples.isEmpty {
                            Sparkline(samples: result.cpuSamples).frame(height: 30).accessibilityLabel("CPU samples: \(result.cpuSamples.map { cpuText($0) }.joined(separator: ", "))")
                            Text("\(result.cpuSamples.count) one-second intervals · average CPU").font(.system(size: 9)).foregroundStyle(Theme.dim)
                        }
                        Text(result.explanation).font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        Text("Measured \(result.checkedAt.formatted(date: .omitted, time: .standard))")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                    DisclosureGroup("Process details") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(result.processes, id: \.identity) { process in
                                Text("PID \(process.identity.pid) · user \(process.identity.uid)")
                                Text(process.identity.path).textSelection(.enabled)
                            }
                            if result.processes.isEmpty { Text("No exact executable match observed.") }
                        }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.dim).padding(.top, 8)
                    }.font(.system(size: 10)).tint(Theme.dim)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Awaiting a scan").font(.system(size: 12, weight: .medium))
                        Text("Check activity and process identity before deciding what to do next.").font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(3)
                    }
                }

            }.padding(18)
        }
        Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 1)
        actions.padding(14)
        }.panel()
    }
    private var actions: some View {
                VStack(spacing: 9) {
                    Button { store.startScan(deep: true) } label: {
                        Label("Take a deeper look", systemImage: "waveform.path.ecg").frame(maxWidth: .infinity)
                    }.buttonStyle(ActionButton()).disabled(store.isBusy)
                    if store.selectedComponent.canRestart {
                        Button { store.requestRestart() } label: {
                            Label("Restart component…", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                        }.buttonStyle(ActionButton()).disabled(store.isBusy || store.selectedResult?.identity == nil)
                        Text("Restarts Notification Center only.\nYou'll review the effect before it runs.")
                            .font(.system(size: 9)).foregroundStyle(Theme.dim).frame(maxWidth: .infinity, alignment: .leading).lineSpacing(3)
                    } else {
                        Text("Inspection available. Restart support for this component is not included yet.")
                            .font(.system(size: 10)).foregroundStyle(Theme.dim).lineSpacing(3)
                    }
                }
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 8, design: .monospaced)).tracking(0.5).foregroundStyle(Theme.dim)
            Text(value).font(.system(size: 20, weight: .light, design: .monospaced)).foregroundStyle(Theme.text)
        }
    }
}

private struct Sparkline: View {
    let samples: [Double]
    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let maximum = max(100, samples.max() ?? 100)
            var path = Path()
            for (index, sample) in samples.enumerated() {
                let point = CGPoint(x: Double(index) / Double(samples.count - 1) * size.width,
                                    y: size.height - max(1, sample / maximum * size.height))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(Theme.cyan.opacity(0.75)), lineWidth: 1)
        }
    }
}
