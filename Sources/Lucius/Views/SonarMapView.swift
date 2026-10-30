import SwiftUI
import LuciusCore

struct SonarMapView: View {
    @Bindable var store: ScanStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("minimalMotion") private var minimalMotion = false
    private var animate: Bool { store.isScanning && !reduceMotion && !minimalMotion && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { context in
            let time = animate ? context.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { geometry in
                ZStack {
                    SonarBackdrop(time: time, active: animate)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Array(Component.catalog.enumerated()), id: \.element.id) { index, component in
                            ComponentTile(component: component, result: store.results.first { $0.id == component.id },
                                          selected: store.selectedID == component.id, scanning: store.isScanning && store.activeComponentIDs.contains(component.id),
                                          index: index, time: time, animate: animate && store.activeComponentIDs.contains(component.id)) { store.selectedID = component.id }
                                .frame(height: max(92, (geometry.size.height - 44) / 3))
                        }
                    }.padding(12)
                    if animate {
                        let fraction = time.truncatingRemainder(dividingBy: 3.2) / 3.2
                        Rectangle().fill(LinearGradient(colors: [.clear, Theme.cyan.opacity(0.07), Theme.cyan.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 70).offset(x: geometry.size.width * fraction - geometry.size.width / 2)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .background(Theme.cyan.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line.opacity(0.6), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Supported component map")
    }
}

private struct SonarBackdrop: View {
    let time: Double
    let active: Bool
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: 0.0, to: size.width, by: 22) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
            for y in stride(from: 0.0, to: size.height, by: 22) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
            context.stroke(grid, with: .color(Theme.cyan.opacity(0.035)), lineWidth: 0.5)
            for i in 0..<5 {
                let radius = Double(i + 1) * 95
                let rect = CGRect(x: size.width / 2 - radius, y: size.height / 2 - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(Theme.cyan.opacity(0.035)), lineWidth: 0.7)
            }
        }.accessibilityHidden(true)
    }
}

private struct ComponentTile: View {
    let component: Component
    let result: ComponentResult?
    let selected: Bool
    let scanning: Bool
    let index: Int
    let time: Double
    let animate: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Theme.surface.opacity(0.94), Theme.background.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ContourField(seed: index, phase: time, animate: animate)
                    .padding(.top, 20).opacity(selected ? 0.85 : 0.4).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: component.symbol).font(.system(size: 17, weight: .medium))
                            .foregroundStyle([Theme.cyan, Theme.violet, Theme.teal, Theme.amber][index % 4])
                        Spacer()
                        Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                    Text(component.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer(minLength: 0)
                    HStack {
                        Circle().fill(Theme.color(for: result?.observation)).frame(width: 4, height: 4)
                        Text(scanning ? "Sampling" : result?.observation.rawValue ?? "Ready to inspect")
                            .font(.system(size: 11)).foregroundStyle(Theme.color(for: result?.observation)).lineLimit(1)
                        Spacer(minLength: 0)
                        if let cpu = result?.averageCPU { Text(cpuText(cpu)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text) }
                    }
                }.padding(13)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Theme.cyan.opacity(0.75) : Theme.line.opacity(0.5), lineWidth: selected ? 1 : 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(component.name), \(result?.observation.rawValue ?? "not scanned")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Abstract contours evoke sonar returns. They are decorative, never measurements.
private struct ContourField: View {
    let seed: Int
    let phase: Double
    let animate: Bool
    var body: some View {
        Canvas { context, size in
            let shift = animate ? sin(phase * 1.3 + Double(seed)) * 3 : 0
            for row in 0..<10 {
                var path = Path()
                for col in 0...34 {
                    let x = Double(col) / 34 * size.width
                    let normalized = Double(col) / 34
                    let mound = exp(-pow((normalized - 0.58) * 4, 2)) * (16 + Double(seed) * 3)
                    let ripple = sin(normalized * 15 + Double(row) * 0.3 + Double(seed)) * 3
                    let y = size.height * 0.54 + Double(row) * 3.3 - mound + ripple + shift
                    if col == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    if col % 2 == 0 {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(Theme.cyan.opacity(0.35)))
                    }
                }
                context.stroke(path, with: .color(Theme.cyan.opacity(row % 3 == 0 ? 0.23 : 0.07)), lineWidth: 0.6)
            }
        }
    }
}
