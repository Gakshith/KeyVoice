import AppKit
import KeyVoiceCore
import KeyVoiceCleanup

/// The menu-bar icon. A single quiet, monochrome SF Symbol microphone that
/// reflects pipeline state — nothing fails invisibly, but nothing shouts either.
@MainActor
final class StatusController {
    private let item: NSStatusItem

    /// Guards the "transient" symbols (checkmark / exclamation): a later state
    /// change invalidates a pending revert so we never stomp fresh state.
    private var revertToken = 0

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setSymbol("mic")

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "KeyVoice", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        let keyItem = NSMenuItem(title: "Set API Key…", action: #selector(setAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
    }

    // MARK: - State

    func update(_ status: PipelineStatus) {
        // Any state change cancels a pending revert to "mic".
        revertToken &+= 1

        switch status {
        case .idle:
            setSymbol("mic")
        case .listening:
            setSymbol("mic.fill")
        case .thinking:
            setSymbol("mic.fill")
        case .inserted, .insertedRaw:
            setSymbol("checkmark.circle")
            scheduleRevert(after: 1.0)
        case .skippedNoSpeech, .abortedTargetLost, .error:
            setSymbol("exclamationmark.circle")
            scheduleRevert(after: 1.2)
        }
    }

    /// Return to the resting "mic" symbol unless a newer state has arrived.
    private func scheduleRevert(after seconds: TimeInterval) {
        let token = revertToken
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.revertToken == token else { return }
            self.setSymbol("mic")
        }
    }

    /// Swap the button's image to a monochrome template SF Symbol. Template
    /// images tint themselves to match the menu bar (light/dark, active/inactive),
    /// so there is no colour and no bounce — just a calm mic.
    private func setSymbol(_ name: String) {
        guard let button = item.button else { return }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "KeyVoice")
        image?.isTemplate = true
        button.image = image
        button.title = ""
    }

    // MARK: - API key

    @objc private func setAPIKey() {
        // .accessory apps have no Dock icon and don't own the menu bar focus,
        // so bring the app forward or the modal opens behind everything.
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
        guard !trimmed.isEmpty else { return }
        try? Keychain.save(trimmed)
    }
}
