import SwiftUI
import LuciusCore

struct ContentView: View {
    @Bindable var store: ScanStore
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store).frame(width: 210)
            Rectangle().fill(Theme.line.opacity(0.6)).frame(width: 1)
            VStack(spacing: 0) {
                Group {
                    switch store.section {
                    case .home: CheckupView(store: store)
                    case .scan: ScanView(store: store)
                    case .diagnostics: DiagnosticsView(store: store)
                    case .hardware: HardwareTestsView(store: store)
                    case .history: HistoryView(store: store)
                    case .about: AboutView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let notice = store.persistenceNotice {
                    Label(notice, systemImage: "exclamationmark.triangle").font(.callout)
                        .foregroundStyle(Theme.amber).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                if store.isBusy { ActivityStatusBar(store: store) }
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
                Image(systemName: "viewfinder.circle.fill").font(.system(size: 29, weight: .medium)).foregroundStyle(Theme.cyan.gradient)
                Text("LUCIUS").font(.system(size: 18, weight: .medium, design: .rounded)).tracking(3)
            }.padding(.bottom, 8)
            Text("A clearer view of your Mac").font(.system(size: 12)).foregroundStyle(Theme.dim)
                .padding(.bottom, 22)
            List(selection: Binding<WorkspaceSection?>(get: { store.section }, set: { if let section = $0 { store.section = section } })) {
                Section("Start") {
                    sidebarRow(.home)
                }
                Section("Tools") {
                    sidebarRow(.scan)
                    sidebarRow(.diagnostics)
                    sidebarRow(.hardware)
                }
                Section("Library") {
                    sidebarRow(.history)
                    sidebarRow(.about)
                }
            }.listStyle(.sidebar).scrollContentBackground(.hidden)
                .padding(.horizontal, -10)
            VStack(alignment: .leading, spacing: 11) {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .buttonStyle(.borderless).font(.system(size: 13)).padding(.bottom, 8)
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
                Text("Lucius 0.4 · Preview").font(.system(size: 10)).foregroundStyle(Theme.dim.opacity(0.7))
            }
        }.padding(.horizontal, 18).padding(.top, 56).padding(.bottom, 24)
        .background(.regularMaterial)
    }

    private func sidebarRow(_ section: WorkspaceSection) -> some View {
        Label {
            Text(section.rawValue)
        } icon: {
            if store.section == section {
                Image(systemName: section.symbol).foregroundStyle(.primary)
            } else {
                Image(systemName: section.symbol).foregroundStyle(Theme.color(for: section))
            }
        }
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 5).tag(section)
    }
}
