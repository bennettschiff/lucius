import SwiftUI
import AppKit
import Charts
import UniformTypeIdentifiers
import LuciusCore

struct HardwareTestsView: View {
    @Bindable var store: ScanStore
    @State private var notice: String?
    private var displayedReport: HardwareReport? {
        store.hardwareReports.first { $0.id == store.selectedHardwareID } ?? store.hardwareReports.first
    }
    private var results: [HardwareTestResult] {
        store.isTesting ? store.hardwareResults : (displayedReport?.results ?? store.hardwareResults)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HARDWARE TEST LAB").eyebrow()
                        Text("Hardware tests").font(.system(size: 29, weight: .bold))
                        Text(store.isTesting ? "Follow each test as it runs." : store.hardwarePhase).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    }
                    Spacer()
                    if store.isTesting {
                        Button(store.isCancelling ? "Stopping…" : "Stop tests") { store.cancel() }.buttonStyle(ActionButton()).disabled(store.isCancelling)
                    } else {
                        Button("Run selected tests") { store.startHardwareTests() }
                            .buttonStyle(ActionButton(primary: true)).disabled(store.isBusy || store.selectedTests.isEmpty)
                    }
                }
                HardwareRunPanel(store: store, results: results,
                                 requested: store.isTesting ? store.hardwareRunTests : (displayedReport?.requested ?? HardwareTest.allCases.filter { store.selectedTests.contains($0) }),
                                 reportDate: store.isTesting ? nil : displayedReport?.date)
                Label(HardwareEngine.coolingDesign(model: HardwareEngine.model), systemImage: "thermometer.medium")
                    .font(.system(size: 13)).foregroundStyle(Theme.cyan)
                Text("These tests briefly use CPU, memory and GPU resources. Each workload has a 20-second deadline and stops for elevated memory or serious thermal pressure at its checkpoints. Keep your Mac on a ventilated surface.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(4)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(HardwareTest.allCases) { test in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: test.symbol)
                                    .font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Theme.color(for: test).gradient, in: RoundedRectangle(cornerRadius: 12))
                                Spacer()
                                if store.activeHardwareTest == test {
                                    Label("Running", systemImage: "waveform.path")
                                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.color(for: test))
                                }
                            }
                            Toggle(isOn: Binding(get: { store.selectedTests.contains(test) }, set: {
                                if $0 { store.selectedTests.insert(test) } else { store.selectedTests.remove(test) }
                            })) { Text(test.title).font(.system(size: 14, weight: .semibold)) }
                                .toggleStyle(.checkbox).disabled(store.isBusy)
                            Text(test.method).font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(4)
                            Text(test.limit).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.color(for: test))
                        }.padding(20).frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading).panel()
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.color(for: test).opacity(store.activeHardwareTest == test ? 0.8 : 0.16), lineWidth: 1))
                    }
                }
                if !store.hardwareReports.isEmpty && !store.isTesting {
                    HStack {
                        Picker("Saved run", selection: Binding(get: { displayedReport?.id ?? UUID() }, set: { store.selectedHardwareID = $0 })) {
                            ForEach(store.hardwareReports) { report in
                                Text(report.date.formatted(date: .abbreviated, time: .standard)).tag(report.id)
                            }
                        }.frame(maxWidth: 380)
                        Spacer()
                        Button("Export detailed report…") { exportReport() }.buttonStyle(ActionButton())
                    }
                    Text("Last 10 runs saved locally, including measurements and sensor samples.").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
                if let notice { Text(notice).foregroundStyle(Theme.cyan) }
                if let notice = store.persistenceNotice { Text(notice).foregroundStyle(Theme.amber) }
                ForEach(results) { result in HardwareResultCard(result: result) }
                Text("A pass applies only to the completed workload. Lucius does not certify the whole machine or control fan speeds.")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
                Link("How to run Apple Diagnostics ↗", destination: URL(string: "https://support.apple.com/102550")!)
                    .font(.system(size: 12))
            }.padding(32)
        }
    }
    private func exportReport() {
        guard let report = displayedReport else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Lucius-hardware-tests.md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try report.markdown.write(to: url, atomically: true, encoding: .utf8); notice = "Detailed report saved." }
            catch { notice = "Export failed: \(error.localizedDescription)" }
        }
    }
}

struct HardwareResultCard: View {
    let result: HardwareTestResult
    private var color: Color {
        switch result.outcome { case .failed, .stopped: Theme.amber; case .passed: Theme.green; case .observed: Theme.teal; case .unavailable: Theme.dim }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(result.test.title, systemImage: result.test.symbol).font(.system(size: 17, weight: .medium))
                Spacer()
                Text(result.outcome.rawValue).foregroundStyle(color)
                Text(String(format: "%.2f s", result.elapsed)).foregroundStyle(Theme.dim)
            }
            Text(result.summary).font(.system(size: 14)).textSelection(.enabled)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 14) {
                ForEach(result.metrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.name.uppercased()).eyebrow()
                        Text(metric.value).font(.system(size: 16, weight: .light, design: .rounded)).foregroundStyle(color).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !result.samples.isEmpty { SensorTrace(samples: result.samples) }
            Text("Coverage: \(result.test.coverage)").font(.system(size: 11)).foregroundStyle(Theme.dim).lineSpacing(4)
            Text(result.nextStep).font(.system(size: 12)).lineSpacing(4)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}

private struct SensorTrace: View {
    let samples: [SensorSample]
    @State private var showFans = false
    private var series: [SensorPoint] {
        samples.enumerated().flatMap { index, sample in
            (showFans ? sample.fanRPM : sample.temperatures).sorted { $0.key < $1.key }.map {
                SensorPoint(id: "\(index)-\($0.key)", elapsed: sample.elapsed, key: $0.key, value: $0.value)
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Sensor trace", selection: $showFans) {
                Text("Temperature (°C)").tag(false); Text("Fan speed (RPM)").tag(true)
            }.pickerStyle(.segmented).frame(maxWidth: 340)
            if series.isEmpty {
                Text(showFans ? "No fan RPM readings available. Fanless Macs have no fan to test." : "No supported temperature readings available on this Mac.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                Chart(series) { point in
                    LineMark(x: .value("Seconds", point.elapsed), y: .value(showFans ? "RPM" : "°C", point.value))
                        .foregroundStyle(by: .value("Sensor", point.key))
                }.chartXAxisLabel("Seconds since observation started").frame(height: 200)
            }
            DisclosureGroup("Raw samples · \(samples.count) readings") {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    let values = (showFans ? sample.fanRPM : sample.temperatures).sorted { $0.key < $1.key }
                        .map { "\($0.key) \(String(format: "%.1f", $0.value))" }.joined(separator: " · ")
                    Text(String(format: "%.1f s", sample.elapsed) + " · " + sample.thermal + " · " + (values.isEmpty ? "No sensor values" : values))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.dim).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
            }.font(.system(size: 12))
        }
    }
}
private struct SensorPoint: Identifiable {
    let id: String
    let elapsed: Double
    let key: String
    let value: Double
}
