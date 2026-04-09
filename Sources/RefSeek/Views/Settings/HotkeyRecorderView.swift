import SwiftUI
import AppKit

// MARK: - Data Model

/// Represents a keyboard shortcut (modifier flags + key character)
struct HotkeyCombination: Equatable {
    var character: String
    var modifiers: NSEvent.ModifierFlags

    /// Human-readable string like "⌘⇧R"
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(character.uppercased())
        return parts.joined()
    }

    /// Load from UserDefaults (returns default ⌘⇧R if not set)
    static func load() -> HotkeyCombination {
        let char = UserDefaults.standard.string(forKey: AppConstants.hotkeyCharacterKey)
            ?? AppConstants.defaultHotkeyCharacter
        let rawMods = UserDefaults.standard.object(forKey: AppConstants.hotkeyModifiersKey) as? UInt
            ?? AppConstants.defaultHotkeyModifiers
        return HotkeyCombination(
            character: char,
            modifiers: NSEvent.ModifierFlags(rawValue: rawMods)
        )
    }

    /// Save to UserDefaults
    func save() {
        UserDefaults.standard.set(character, forKey: AppConstants.hotkeyCharacterKey)
        UserDefaults.standard.set(modifiers.rawValue, forKey: AppConstants.hotkeyModifiersKey)
    }
}

// MARK: - SwiftUI Wrapper

/// A SwiftUI view that displays the current hotkey and lets the user record a new one by clicking and pressing keys.
struct HotkeyRecorderView: View {
    @Binding var combination: HotkeyCombination
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            // Display box
            Button {
                isRecording.toggle()
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.orange)
                        Text("Press shortcut…")
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "command")
                            .foregroundStyle(.secondary)
                        Text(combination.displayString)
                            .fontWeight(.medium)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 140)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .background(
                // Invisible key event catcher when recording
                KeyEventCatcher(isRecording: $isRecording, combination: $combination)
                    .frame(width: 0, height: 0)
            )

            if isRecording {
                Button("Cancel") {
                    isRecording = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("Reset") {
                combination = HotkeyCombination(
                    character: AppConstants.defaultHotkeyCharacter,
                    modifiers: NSEvent.ModifierFlags(rawValue: AppConstants.defaultHotkeyModifiers)
                )
                combination.save()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }
}

// MARK: - NSView Key Catcher

/// An NSViewRepresentable that captures key events when recording mode is active
struct KeyEventCatcher: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var combination: HotkeyCombination

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyDown = { event in
            handleKey(event)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.isActive = isRecording
        if isRecording {
            // Make it first responder so it receives key events
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    private func handleKey(_ event: NSEvent) {
        guard isRecording else { return }

        // Escape cancels recording
        if event.keyCode == 53 { // Escape key
            isRecording = false
            return
        }

        // Require at least one modifier (⌘, ⌃, ⌥) for a global hotkey
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let hasMainModifier = mods.contains(.command) || mods.contains(.control) || mods.contains(.option)

        guard hasMainModifier,
              let chars = event.charactersIgnoringModifiers,
              !chars.isEmpty else {
            return
        }

        combination = HotkeyCombination(character: chars.lowercased(), modifiers: mods)
        combination.save()
        isRecording = false
    }
}

/// A simple NSView subclass that can become first responder to capture key events
class KeyCatcherView: NSView {
    var isActive = false
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { isActive }

    override func keyDown(with event: NSEvent) {
        if isActive {
            onKeyDown?(event)
        } else {
            super.keyDown(with: event)
        }
    }

    // Suppress the system beep for unhandled keys
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isActive {
            onKeyDown?(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
