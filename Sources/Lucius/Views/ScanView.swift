import SwiftUI
import LuciusCore

struct ScanView: View {
    @Bindable var store: ScanStore
    private let suggestions = ["A notification is stuck", "Dock won't respond", "Previews won't open", "I'm not sure"]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("SYSTEM OBSERVATORY").eyebrow()
                Spacer()
                Label("On-device checks", systemImage: "internaldrive").font(.system(size: 10)).foregroundStyle(Theme.dim)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.resultHeadline).font(.system(size: 29, weight: .light)).tracking(-0.7)
                    Text(store.phase).font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(2)
                }
                Spacer(minLength: 12)
                if store.isScanning {
                    Button { store.cancel() } label: { Label("Cancel", systemImage: "xmark") }.buttonStyle(ActionButton())
                } else {
                    Button { store.startScan() } label: { Label(store.results.isEmpty ? "Scan my Mac" : "Scan again", systemImage: "viewfinder") }
                        .buttonStyle(ActionButton(primary: true)).disabled(store.isBusy).keyboardShortcut(.return, modifiers: .command)
                }
            }
            symptomInput
            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(Theme.amber)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).panel()
            }
            if let message = store.recoveryMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.cyan)
                    if store.awaitingConfirmation {
                        HStack {
                            Button("Yes, it cleared") { store.confirmRecovery(true) }.buttonStyle(ActionButton(primary: true))
                            Button("Still stuck") { store.confirmRecovery(false) }.buttonStyle(ActionButton())
                        }
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).panel()
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("COMPONENT MAP").eyebrow()
                        Spacer()
                        Text(store.isScanning ? "ACQUIRING OBSERVATIONS" : "06 SUPPORTED COMPONENTS").font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(Theme.dim)
                    }
                    SonarMapView(store: store).frame(maxHeight: .infinity)
                    HStack(spacing: 16) {
                        legend("Observed", color: Theme.cyan)
                        legend("Investigate", color: Theme.amber)
                        legend("Unchecked / unavailable", color: Theme.dim)
                        Spacer(minLength: 0)
                    }
                }.frame(maxWidth: .infinity)
                InspectorView(store: store).frame(width: 262)
            }.frame(maxHeight: .infinity)
            footer
        }.padding(.horizontal, 28).padding(.top, 39).padding(.bottom, 22)
    }

    private var symptomInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass").foregroundStyle(Theme.cyan)
                TextField("What's happening? Describe a symptom, or leave this blank.", text: $store.symptom)
                    .textFieldStyle(.plain).font(.system(size: 12)).accessibilityLabel("What's happening?")
                    .onSubmit { store.startScan() }.disabled(store.isBusy)
                Text("OPTIONAL").font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(Theme.dim)
            }
            HStack(spacing: 7) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        store.symptom = suggestion == "I'm not sure" ? "" : suggestion
                        store.selectedID = Component.ordered(for: store.symptom)[0].id
                    } label: {
                        Text(suggestion).font(.system(size: 10)).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.line.opacity(0.30), in: Capsule()).foregroundStyle(Theme.dim)
                    }.buttonStyle(.plain).disabled(store.isBusy)
                }
            }
        }.padding(15).panel()
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: store.isScanning ? "waveform.path" : "scope").font(.system(size: 20, weight: .ultraLight)).foregroundStyle(Theme.cyan)
            VStack(alignment: .leading, spacing: 5) {
                Text(store.isScanning ? "A few observations. A clearer picture." : "Observation first. You decide what changes.")
                    .font(.system(size: 11, weight: .medium))
                Text("CPU activity isn't proof of a freeze. Checks cover six interface components, not every Mac service.")
                    .font(.system(size: 10)).foregroundStyle(Theme.dim)
            }
            Spacer()
            if store.isScanning {
                ProgressView(value: store.progress).frame(width: 90).tint(Theme.cyan)
                    .accessibilityLabel("Scan progress")
            } else if let date = store.lastScanAt {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("LAST COMPLETE SCAN").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.dim)
                    Text(date, style: .time).font(.system(size: 10, design: .monospaced))
                }
            }
        }.padding(.top, 4)
    }

    private func legend(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(label).font(.system(size: 8)).foregroundStyle(Theme.dim)
        }
    }
}
