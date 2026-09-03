import AppKit
import KeyVoiceCore
import KeyVoiceCleanup

/// The menu-bar icon. A single quiet, monochrome SF Symbol waveform (matching the app's keycap-wave
/// mark) that reflects pipeline state,
/// plus the app's quick actions (open the Hub, permissions, API key, quit).
@MainActor
final class StatusController {
    private let item: NSStatusItem
    private let onOpenHub: () -> Void
    private let onOpenSettings: () -> Void
    private let onPermissions: () -> Void

    /// Guards the transient symbols (checkmark / exclamation): a later state change invalidates a
    /// pending revert so we never stomp fresh state.
    private var revertToken = 0

    init(onOpenHub: @escaping () -> Void, onOpenSettings: @escaping () -> Void, onPermissions: @escaping () -> Void) {
        self.onOpenHub = onOpenHub
        self.onOpenSettings = onOpenSettings
        self.onPermissions = onPermissions
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setSymbol("waveform")

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "KeyVoice", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        menu.addItem(makeItem("Open KeyVoice", #selector(openHub)))
        menu.addItem(makeItem("Settings…", #selector(openSettings)))
        menu.addItem(makeItem("Permissions…", #selector(openPermissions)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    // MARK: - State

    func update(_ status: PipelineStatus) {
        revertToken &+= 1
        item.button?.toolTip = nil

        switch status {
        case .idle:
            setSymbol("waveform")
        case .listening:
            setSymbol("waveform.circle.fill")
        case .thinking:
            setSymbol("waveform.circle.fill")
        case .inserted, .insertedRaw:
            setSymbol("checkmark.circle")
            scheduleRevert(after: 1.0)
        case .skippedNoSpeech, .abortedTargetLost:
            setSymbol("exclamationmark.circle")
            scheduleRevert(after: 1.2)
        case .error(let message):
            setSymbol("exclamationmark.circle")
            item.button?.toolTip = message
        }
    }

    private func scheduleRevert(after seconds: TimeInterval) {
        let token = revertToken
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.revertToken == token else { return }
            self.setSymbol("waveform")   // return to the neutral resting glyph (never the old drop icon)
        }
    }

    private func setSymbol(_ name: String) {
        guard let button = item.button else { return }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "KeyVoice")
        image?.isTemplate = true
        button.image = image
        button.title = ""
    }

    // MARK: - Actions

    @objc private func openHub() { onOpenHub() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func openPermissions() { onPermissions() }

    /// Presents the Anthropic API-key dialog. Public so the Hub's Settings can trigger the same flow.
    func promptForAPIKey() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Anthropic API Key"
        alert.informativeText = "Used to clean up transcripts. Stored in your login Keychain."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "sk-ant-…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let empty = NSAlert()
            empty.messageText = "No key entered"
            empty.informativeText = "Nothing was saved."
            empty.runModal()
            return
        }

        do {
            try Keychain.save(trimmed)
        } catch {
            Log.error("Failed to save API key: \(error)")
            let errorAlert = NSAlert()
            errorAlert.messageText = "Couldn’t save the key"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.runModal()
        }
    }
}
