import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// Explicit alias selects the macOS 14 property wrapper with newer SDKs,
// including command-line toolchains that do not bundle SwiftUI macro plugins.
private typealias StoredState<Value> = SwiftUI.State<Value>

@main
struct LuciusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StoredState private var store = ScanStore()
    var body: some Scene {
        WindowGroup("Lucius", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1120, minHeight: 740)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1320, height: 850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Scan") {
                Button("Scan My Mac") { store.startScan() }.keyboardShortcut("r", modifiers: .command).disabled(store.isBusy)
                Button("Cancel Scan") { store.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!store.isScanning)
            }
        }
        Settings { SettingsView().preferredColorScheme(.dark) }
    }
}
