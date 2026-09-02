import AppKit
import KeyVoiceCore
import KeyVoiceHotkey
import KeyVoiceInsert
import KeyVoiceAudio
import KeyVoiceCleanup
import KeyVoiceHUD

/// Wires the concrete implementations into the Coordinator and owns app lifetime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: Coordinator?
    private var status: StatusController?
    private var hud: HUDController?
    private var levelMeter: AudioLevelMeter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar (.accessory) app has no main menu, so ⌘X/⌘C/⌘V/⌘A have nothing to route
        // through and paste fails in our text fields (e.g. Set API Key). Install a standard Edit
        // menu — its key equivalents work even though the menu bar itself isn't shown.
        installEditMenu()

        let config = AppConfig()

        let status = StatusController()
        let hud = HUDController(config: config)
        let levelMeter = AudioLevelMeter()
        self.status = status
        self.hud = hud
        self.levelMeter = levelMeter

        let coordinator = Coordinator(
            hotkey: HotkeyMonitor(config: config),
            audio: MicAudioCapture(config: config),
            transcriber: SpeechTranscriberEngine(),   // Apple on-device (macOS 26); Apple-only, no fallback
            cleaner: ClaudeCleaner(config: config),
            inserter: PasteInserter(config: config),
            targets: AXTargetProvider(),
            config: config
        )

        // Status fans out to both the menu bar and the on-screen HUD.
        coordinator.onStatus = { [weak status, weak hud] s in
            status?.update(s)
            hud?.update(s)
        }
        // Live mic level → meter → HUD (passive tap alongside the transcriber).
        coordinator.audioMonitor = { [weak levelMeter] buffer in levelMeter?.process(buffer) }
        levelMeter.onLevel = { [weak hud] level in hud?.setLevel(level) }

        do {
            try coordinator.start()
        } catch {
            Log.error("startup failed: \(error.localizedDescription)")
            status.update(.error(error.localizedDescription))
        }
        self.coordinator = coordinator
    }

    /// Installs a minimal main menu with a standard Edit menu so the system editing shortcuts
    /// (Cut/Copy/Paste/Select All) reach the first responder's field editor. Without this, an
    /// accessory app's text fields accept typing but not ⌘V. Targets are nil → responder chain.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
