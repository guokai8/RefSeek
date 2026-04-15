import SwiftUI
import AppKit

@main
struct RefSeekApp: App {
    @StateObject private var store = PaperStore()
    @StateObject private var embeddingStore = EmbeddingStore()
    @NSApplicationDelegateAdaptor(RefSeekDelegate.self) var appDelegate

    init() {
        // CRITICAL: Must set activation policy before SwiftUI creates windows.
        // Without this, raw binaries (non-.app) default to .prohibited and
        // no windows will be created.
        NSApplication.shared.setActivationPolicy(.regular)
        // Disable window state restoration to prevent "0 windows" restore
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        WindowGroup("RefSeek") {
            ContentView()
                .environmentObject(store)
                .environmentObject(embeddingStore)
                .task {
                    // Index paper embeddings on launch (Apple ML — instant)
                    await embeddingStore.indexPapers(store.papers)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

/// Shared state for global search trigger (PopClip-like)
class GlobalSearchState: ObservableObject {
    static let shared = GlobalSearchState()
    @Published var pendingQuery: String?
}

final class RefSeekDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    private var signalFileTimer: Timer?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set custom app icon from bundled resources
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png", subdirectory: "Resources"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        // Setup menu bar status item (works on macOS 12+)
        setupStatusItem()

        // Register global hotkey: user-configurable (default ⌘⇧R) to search selected text from any app
        registerGlobalHotkey()

        // Re-register when the hotkey preference changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerGlobalHotkey()
        }

        // Poll for Quick Action signal file (written by the right-click "Search in RefSeek" service)
        signalFileTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForQuickActionSignal()
        }

        // Delayed activation to let SwiftUI create the window first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            // Force any existing window to front, visible on all Spaces
            for window in NSApp.windows where window.canBecomeMain {
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Check for Quick Action signal when the app is brought to front
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.checkForQuickActionSignal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        signalFileTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }

    // MARK: - Quick Action Signal File

    /// Check if the Quick Action wrote a signal file with selected text
    private func checkForQuickActionSignal() {
        guard let query = QuickActionInstaller.consumeSignalFile() else { return }
        DispatchQueue.main.async {
            GlobalSearchState.shared.pendingQuery = query
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
        }
    }

    // MARK: - Global Hotkey

    /// Register (or re-register) the global hotkey monitor from UserDefaults
    private func registerGlobalHotkey() {
        // Remove existing monitor first
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        let combo = HotkeyCombination.load()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let pressedMods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            let expectedMods = combo.modifiers.intersection([.command, .control, .option, .shift])
            if pressedMods == expectedMods && event.charactersIgnoringModifiers?.lowercased() == combo.character {
                self?.handleGlobalSearch()
            }
        }
    }

    /// Handle global hotkey: read clipboard/selection, bring RefSeek to front, populate search
    private func handleGlobalSearch() {
        // The selected text should be on the clipboard after ⌘C,
        // but since the user is selecting, we read the general pasteboard
        let pasteboard = NSPasteboard.general
        guard let selectedText = pasteboard.string(forType: .string),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let query = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Limit to reasonable length
        let trimmedQuery = String(query.prefix(200))

        DispatchQueue.main.async {
            GlobalSearchState.shared.pendingQuery = trimmedQuery
            // Bring RefSeek to front
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
        }
    }

    // MARK: - Menu Bar Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "RefSeek")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open RefSeek", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Search from Clipboard", action: #selector(searchFromClipboard), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
    }

    @objc private func searchFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        GlobalSearchState.shared.pendingQuery = trimmed
        openMainWindow()
    }
}
