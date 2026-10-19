import SwiftUI
import LuciusCore

struct ContentView: View {
    @Bindable var store: ScanStore
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store).frame(width: 185)
            Rectangle().fill(Theme.line.opacity(0.6)).frame(width: 1)
            Group {
                switch store.section {
                case .scan: ScanView(store: store)
                case .diagnostics: DiagnosticsView(store: store)
                case .history: HistoryView(store: store)
                case .about: AboutView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .tint(Theme.cyan)
        .alert("Restart Notification Center?", isPresented: $store.confirmRestart) {
            Button("Cancel", role: .cancel) { store.pendingIdentity = nil }
            Button("Restart") { store.restart() }
        } message: {
            Text("Notification banners and Notification Center will briefly disappear. Lucius will send a normal termination request to your verified Notification Center process and wait up to 10 seconds for macOS to relaunch it. Messages will not be targeted. This cannot guarantee the stuck banner clears.")
        }
    }
}

struct SidebarView: View {
    @Bindable var store: ScanStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder.circle").font(.system(size: 29, weight: .ultraLight)).foregroundStyle(Theme.cyan)
                Text("LUCIUS").font(.system(size: 18, weight: .medium, design: .rounded)).tracking(3)
            }.padding(.bottom, 8)
            Text("A clearer view of your Mac").font(.system(size: 10)).foregroundStyle(Theme.dim)
                .padding(.bottom, 42)
            Text("WORKSPACE").eyebrow().padding(.bottom, 16)
            ForEach(WorkspaceSection.allCases, id: \.self) { section in
                Button { store.section = section } label: {
                    HStack(spacing: 11) {
                        Image(systemName: section.symbol).frame(width: 17)
                        Text(section.rawValue).font(.system(size: 12, weight: .medium))
                        Spacer(minLength: 0)
                    }.foregroundStyle(store.section == section ? Theme.cyan : Theme.dim)
                        .padding(.horizontal, 10).padding(.vertical, 12)
                        .background(store.section == section ? Theme.cyan.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Circle().fill(store.isBusy ? Theme.cyan : Theme.dim).frame(width: 5, height: 5)
                    Text(store.isBusy ? "CHECK IN PROGRESS" : "ON DEMAND").eyebrow()
                }
                Text("Only working when\nyou ask it to.").font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(4)
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 8)
                HStack {
                    Text("LOCAL BY DESIGN").font(.system(size: 8, design: .monospaced)).tracking(1)
                    Spacer()
                    Image(systemName: "lock.shield").font(.system(size: 12))
                }.foregroundStyle(Theme.dim)
                Text("Lucius 0.2 · Preview").font(.system(size: 10)).foregroundStyle(Theme.dim.opacity(0.7))
            }
        }.padding(.horizontal, 18).padding(.top, 56).padding(.bottom, 24)
        .background(Theme.surface.opacity(0.35))
    }
}
