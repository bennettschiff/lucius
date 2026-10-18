import Foundation

public struct Component: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String
    public let category: String
    public let purpose: String
    public let symptoms: [String]
    public let paths: [String]
    public var canRestart: Bool { id == "notifications" }

    public static let catalog: [Component] = [
        .init(id: "notifications", name: "Notification Center", symbol: "bell.badge", category: "NOTIFICATIONS",
              purpose: "Displays notification banners and Notification Center. A stuck banner can belong here even while the app that sent it works normally.",
              symptoms: ["notification", "banner", "alert", "messages"],
              paths: ["/System/Library/CoreServices/NotificationCenter.app/Contents/MacOS/NotificationCenter"]),
        .init(id: "dock", name: "Dock", symbol: "dock.rectangle", category: "DESKTOP",
              purpose: "Presents the Dock and participates in desktop features such as Mission Control. Resource activity alone cannot tell us whether these controls respond.",
              symptoms: ["dock", "mission control", "spaces", "desktop"],
              paths: ["/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock"]),
        .init(id: "finder", name: "Finder", symbol: "folder", category: "FILES",
              purpose: "Manages file browsing and desktop icons. File operations can legitimately use CPU; a resource spike does not establish a freeze.",
              symptoms: ["finder", "folder", "file", "desktop"],
              paths: ["/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"]),
        .init(id: "control", name: "Control Center", symbol: "switch.2", category: "CONTROLS",
              purpose: "Presents quick controls in the menu bar. This scan measures the interface process; it does not test Wi-Fi, Bluetooth, or audio hardware.",
              symptoms: ["control", "wifi", "wi-fi", "bluetooth", "sound", "volume", "brightness"],
              paths: ["/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"]),
        .init(id: "menu", name: "Menu Bar", symbol: "menubar.rectangle", category: "SYSTEM UI",
              purpose: "SystemUIServer hosts some system menu-bar items. Other items can belong to Control Center or individual apps and are outside this check.",
              symptoms: ["menu", "clock", "status"],
              paths: ["/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer"]),
        .init(id: "preview", name: "Quick Look", symbol: "doc.text.magnifyingglass", category: "PREVIEWS",
              purpose: "Presents file previews. This service starts on demand, so not observing it is often normal. Individual preview extensions are not covered by this check.",
              symptoms: ["preview", "quick look", "spacebar", "space bar", "thumbnail"],
              paths: ["/System/Library/Frameworks/QuickLookUI.framework/Versions/A/XPCServices/QuickLookUIService.xpc/Contents/MacOS/QuickLookUIService",
                      "/System/Library/Frameworks/Quartz.framework/Versions/A/Frameworks/QuickLookUI.framework/Versions/A/XPCServices/QuickLookUIService.xpc/Contents/MacOS/QuickLookUIService"])
    ]

    public static func ordered(for symptom: String) -> [Component] {
        let query = symptom.lowercased()
        return catalog.enumerated().sorted {
            let lhs = $0.element.symptoms.filter { query.contains($0) }.count
            let rhs = $1.element.symptoms.filter { query.contains($0) }.count
            return lhs == rhs ? $0.offset < $1.offset : lhs > rhs
        }.map(\.element)
    }

    public func matches(symptom: String) -> Bool {
        !symptom.isEmpty && symptoms.contains { symptom.lowercased().contains($0) }
    }
}
