import Foundation
import ImageIO

public enum SelectedDiagnostics {
    public static func applications(_ urls: [URL], onUpdate: @Sendable ([DiagnosticFinding]) async -> Void) async throws {
        for url in urls.prefix(10) {
            try Task.checkCancellation()
            let attributes = try? url.resourceValues(forKeys: [.volumeIsLocalKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
            guard attributes?.volumeIsLocal == true,
                  attributes?.isUbiquitousItem != true || attributes?.ubiquitousItemDownloadingStatus == .current else {
                await onUpdate([.init(.applications, url.lastPathComponent, .unavailable, "Local app required", "Select a downloaded app on a local volume. Network volumes and cloud placeholders are excluded.")]); continue
            }
            guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url) else {
                await onUpdate([.init(.applications, url.lastPathComponent, .unavailable, "Not an application bundle", "Select a local .app bundle to inspect.")]); continue
            }
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            var findings = [DiagnosticFinding(.applications, url.lastPathComponent, .information, "Version \(version)",
                                              "Bundle identifier: \(bundle.bundleIdentifier ?? "Unavailable"). Metadata is supplied by the application and does not establish safety.")]
            do {
                let signature = try await DiagnosticCommand.run("/usr/bin/codesign", ["--verify", "--strict", url.path], seconds: 5)
                findings.append(.init(.applications, "\(url.lastPathComponent) · signature", signature.interrupted ? .unavailable : (signature.succeeded ? .observed : .attention),
                                      signature.interrupted ? "Check exceeded its budget" : (signature.succeeded ? "Signature verification succeeded" : "Signature needs review"),
                                      "Local code-signature verification. Unsigned, modified and locally built apps may fail. Success does not prove notarization, malware safety, or compatibility. Nested code is not exhaustively inspected."))
                if let executable = bundle.executableURL {
                    let architecture = try await DiagnosticCommand.run("/usr/bin/lipo", ["-archs", executable.path], seconds: 2)
                    findings.append(.init(.applications, "\(url.lastPathComponent) · architecture", architecture.succeeded ? .information : .unavailable,
                                          architecture.succeeded ? String(architecture.text.prefix(160)) : "Unavailable",
                                          "Architectures in the main executable. A compatible architecture does not guarantee an app works on this macOS release."))
                }
            } catch is CancellationError { throw CancellationError() }
            catch { findings.append(.init(.applications, url.lastPathComponent, .unavailable, "Inspection unavailable", "The inspection utility could not run.")) }
            try Task.checkCancellation()
            await onUpdate(findings)
        }
    }

    public static func files(_ urls: [URL], onUpdate: @Sendable ([DiagnosticFinding]) async -> Void) async throws {
        for url in urls.prefix(20) {
            try Task.checkCancellation()
            await onUpdate([validateFile(url)])
        }
    }

    static func validateFile(_ url: URL) -> DiagnosticFinding {
        let name = url.lastPathComponent
        let unsupported = DiagnosticFinding(.files, name, .unavailable, "Format not supported", "This version checks JSON, property lists, and PNG/JPEG/GIF image headers. It does not repair or rewrite files.")
        guard ["json", "plist", "png", "jpg", "jpeg", "gif"].contains(url.pathExtension.lowercased()) else { return unsupported }
        do {
            let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
                                                              .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .volumeIsLocalKey])
            guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
                  attributes.volumeIsLocal == true,
                  let size = attributes.fileSize, size <= 4_194_304 else {
                return .init(.files, name, .unavailable, "Skipped", "Only regular local files up to 4 MiB are inspected; symbolic links and network volumes are excluded.")
            }
            if attributes.isUbiquitousItem == true && attributes.ubiquitousItemDownloadingStatus != .current {
                return .init(.files, name, .unavailable, "Cloud file skipped", "Download this file yourself before checking it. Lucius does not request a cloud download.")
            }
            // Limit the actual read too: a file can grow after the metadata check.
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 4_194_305) ?? Data()
            guard data.count <= 4_194_304 else {
                return .init(.files, name, .unavailable, "Size changed", "The file grew beyond the 4 MiB check limit.")
            }
            let detail: String
            switch url.pathExtension.lowercased() {
            case "json":
                _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                detail = "JSON syntax parsed successfully. This does not validate an application's schema or the meaning of its data."
            case "plist":
                _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                detail = "Property-list syntax parsed successfully. This does not establish that its settings are correct for an application."
            default:
                guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                      CGImageSourceGetCount(source) > 0,
                      CGImageSourceGetStatus(source) == .statusComplete,
                      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil else {
                    return .init(.files, name, .attention, "Image header could not be read", "The file may be incomplete, mislabeled or unsupported. This is not a definitive corruption diagnosis.")
                }
                detail = "Image container and first-frame metadata were readable. Pixel data and later animation frames were not fully decoded or validated."
            }
            return .init(.files, name, .observed, "\(byteLabel(Int64(data.count))) · structure readable", detail)
        } catch {
            let cocoa = error as NSError
            let inaccessible = cocoa.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileReadNoSuchFileError, NSFileReadUnknownError].contains(cocoa.code)
            return .init(.files, name, inaccessible ? .unavailable : .attention,
                         inaccessible ? "File could not be accessed" : "Structure could not be parsed",
                         "The selected file may be inaccessible, incomplete, malformed or unsupported. No changes were made; inspect the original in its own app.")
        }
    }
}
