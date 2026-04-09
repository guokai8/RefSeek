import Foundation

/// Installs a macOS Service that lets users right-click selected text in any app
/// → Services → "Search in RefSeek".
///
/// Strategy: Compile a tiny Cocoa service app with `swiftc` that properly
/// implements `NSServicesProvider`. The app registers itself as a services
/// provider, receives text via `NSPasteboard`, writes it to a signal file,
/// and activates RefSeek. This is the only reliable way for macOS to
/// discover and invoke a service from the right-click → Services menu.
enum QuickActionInstaller {

    static let appName = "SearchInRefSeek"
    static let serviceLabel = "Search in RefSeek"
    static let signalFileName = ".refseek_search"
    static let bundleIdentifier = "com.refseek.service"

    /// Path to ~/Library/Services/<name>.app
    static var serviceAppURL: URL {
        let services = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
        return services.appendingPathComponent("\(appName).app", isDirectory: true)
    }

    /// Path to the signal file the service writes
    static var signalFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(signalFileName)
    }

    /// Whether the service is currently installed
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: serviceAppURL.path)
    }

    // MARK: - Install

    /// Build and install the service .app bundle using swiftc
    static func install() throws {
        let fm = FileManager.default

        // Ensure ~/Library/Services exists
        let servicesDir = serviceAppURL.deletingLastPathComponent()
        try fm.createDirectory(at: servicesDir, withIntermediateDirectories: true)

        // Remove old version if exists
        if fm.fileExists(atPath: serviceAppURL.path) {
            try fm.removeItem(at: serviceAppURL)
        }

        // Step 1: Write the Swift source for the service helper app
        let swiftSource = buildSwiftSource()
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("refseek_service_build")
        try? fm.removeItem(at: tmpDir)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let srcFile = tmpDir.appendingPathComponent("main.swift")
        try swiftSource.write(to: srcFile, atomically: true, encoding: .utf8)

        // Step 2: Create .app bundle structure
        let macosDir = serviceAppURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resourcesDir = serviceAppURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
        try fm.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Step 3: Compile with swiftc
        let executablePath = macosDir.appendingPathComponent(appName).path
        let compile = Process()
        compile.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        compile.arguments = [
            srcFile.path,
            "-o", executablePath,
            "-framework", "Cocoa",
            "-suppress-warnings",
        ]
        let errPipe = Pipe()
        compile.standardError = errPipe
        try compile.run()
        compile.waitUntilExit()

        // Clean up temp dir
        try? fm.removeItem(at: tmpDir)

        guard compile.terminationStatus == 0 else {
            // Clean up partial .app
            try? fm.removeItem(at: serviceAppURL)
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "QuickActionInstaller", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "swiftc failed: \(errMsg)"])
        }

        // Step 4: Write Info.plist with NSServices
        let infoPlist = buildInfoPlist()
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist, format: .xml, options: 0)
        try plistData.write(to: serviceAppURL
            .appendingPathComponent("Contents/Info.plist"))

        // Step 5: Register with Launch Services & Pasteboard Server
        registerService()
    }

    // MARK: - Uninstall

    static func uninstall() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: serviceAppURL.path) {
            try fm.removeItem(at: serviceAppURL)
            flushPBS()
        }
    }

    // MARK: - Signal File

    /// Read and consume the signal file (returns the query, or nil)
    static func consumeSignalFile() -> String? {
        let url = signalFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try FileManager.default.removeItem(at: url)
            return text.isEmpty ? nil : String(text.prefix(500))
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Private: Swift Source

    /// The Swift source for the minimal Cocoa service helper app.
    /// It registers as an NSServices provider, handles the service message
    /// by writing selected text to the signal file, then activates RefSeek.
    private static func buildSwiftSource() -> String {
        let signalPath = signalFileURL.path
        return """
        import Cocoa

        class ServiceProvider: NSObject {
            /// Called by macOS when user selects "Search in RefSeek" from Services menu.
            /// Selector: searchInRefSeek(_:userData:error:) matches NSMessage "searchInRefSeek".
            @objc func searchInRefSeek(
                _ pboard: NSPasteboard,
                userData: String,
                error: AutoreleasingUnsafeMutablePointer<NSString>
            ) {
                guard let text = pboard.string(forType: .string),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmed = String(query.prefix(500))

                // Write to signal file for RefSeek to pick up
                let signalPath = "\(signalPath)"
                try? trimmed.write(toFile: signalPath, atomically: true, encoding: .utf8)

                // Activate RefSeek
                for app in NSWorkspace.shared.runningApplications {
                    if app.localizedName == "RefSeek" || app.bundleIdentifier == "RefSeek" {
                        app.activate()
                        break
                    }
                }

                // Quit the helper after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    NSApp.terminate(nil)
                }
            }
        }

        class AppDelegate: NSObject, NSApplicationDelegate {
            let provider = ServiceProvider()

            func applicationDidFinishLaunching(_ notification: Notification) {
                NSApp.servicesProvider = provider

                // Auto-quit after 30 seconds if no service call comes
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    NSApp.terminate(nil)
                }
            }
        }

        let app = NSApplication.shared
        // Don't show in Dock or app switcher
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        """
    }

    // MARK: - Private: Info.plist

    private static func buildInfoPlist() -> [String: Any] {
        return [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": appName,
            "CFBundleExecutable": appName,
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0",
            "LSMinimumSystemVersion": "14.0",
            "LSUIElement": true,   // Hide from Dock
            "NSServices": [
                [
                    "NSMenuItem": [
                        "default": serviceLabel
                    ],
                    "NSMessage": "searchInRefSeek",
                    "NSSendTypes": ["NSStringPboardType"],
                    "NSPortName": appName,
                ] as [String : Any]
            ],
        ]
    }

    // MARK: - Private: Registration

    /// Register the .app with Launch Services and flush pbs
    private static func registerService() {
        // Register with Launch Services
        let lsregister = Process()
        lsregister.executableURL = URL(fileURLWithPath:
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
        lsregister.arguments = ["-R", "-f", serviceAppURL.path]
        try? lsregister.run()
        lsregister.waitUntilExit()

        // Flush the Pasteboard Server cache
        flushPBS()
    }

    private static func flushPBS() {
        let pbs = Process()
        pbs.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        pbs.arguments = ["-flush"]
        try? pbs.run()
        pbs.waitUntilExit()

        let pbsUpdate = Process()
        pbsUpdate.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        pbsUpdate.arguments = ["-update"]
        try? pbsUpdate.run()
        pbsUpdate.waitUntilExit()
    }
}
