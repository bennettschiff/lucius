import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: ScanStore?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store, store.isBusy else { return .terminateNow }
        Task {
            await store.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
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
    @AppStorage("appearance") private var appearance = "light"
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StoredState private var store = ScanStore()
    var body: some Scene {
        WindowGroup("Lucius", id: "main") {
            ContentView(store: store)
                .onAppear { delegate.store = store }
                .frame(minWidth: 1040, minHeight: 700)
                .preferredColorScheme(appearance == "system" ? nil : (appearance == "dark" ? .dark : .light))
        }
        .defaultSize(width: 1320, height: 850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Checks") {
                Button("Quick Checkup") { store.startCheckup(.quick) }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(store.isBusy)
                Button("Extended Checkup") { store.startCheckup(.extended) }.disabled(store.isBusy)
                Divider()
                Button("Scan Interface Components") { store.startScan() }.keyboardShortcut("r", modifiers: .command).disabled(store.isBusy)
                Button("Run System Overview") { store.startDiagnostics() }.disabled(store.isBusy || store.selectedChecks.isEmpty)
                Button("Run Hardware Tests") { store.startHardwareTests() }.disabled(store.isBusy || store.selectedTests.isEmpty)
                Button("Cancel Check") { store.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!store.isBusy)
            }
        }
        Settings {
            SettingsView().preferredColorScheme(appearance == "system" ? nil : (appearance == "dark" ? .dark : .light))
        }
    }
}
