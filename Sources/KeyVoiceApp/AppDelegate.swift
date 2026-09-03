import AppKit
import KeyVoiceCore
import KeyVoiceHotkey
import KeyVoiceInsert
import KeyVoiceAudio
import KeyVoiceCleanup
import KeyVoiceHUD
import KeyVoiceStore

/// Wires the concrete implementations into the Coordinator and owns app lifetime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: Coordinator?
    private var status: StatusController?
    private var hud: HUDController?
    private var caption: CaptionController?
    private var levelMeter: AudioLevelMeter?
    private var store: Store?
    private var settings: SettingsStore?
    private var windowManager: WindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar (.accessory) app has no main menu, so ⌘X/⌘C/⌘V/⌘A have nothing to route
        // through and paste fails in our text fields (e.g. Set API Key). Install a standard Edit
        // menu — its key equivalents work even though the menu bar itself isn't shown.
        installEditMenu()

        let store = Store()
        let settings = SettingsStore()
        self.store = store
        self.settings = settings

        // Seed runtime config from the user's saved settings.
        var config = AppConfig()
        config.rightOptionKeyCode = Int64(settings.hotKeyCode)

        let windowManager = WindowManager(
            store: store, settings: settings,
            onSetAPIKey: { [weak self] in self?.status?.promptForAPIKey() },
            onRearm: { [weak self] in self?.rearm() }
        )
        self.windowManager = windowManager

        let status = StatusController(
            onOpenHub: { windowManager.showHub() },
            onOpenSettings: { windowManager.showSettings() },
            onPermissions: { windowManager.showOnboarding() }
        )
        let hud = HUDController(config: config)
        let caption = CaptionController()
        let levelMeter = AudioLevelMeter()
        self.status = status
        self.hud = hud
        self.caption = caption
        self.levelMeter = levelMeter

        // Apple on-device streaming transcriber (macOS 26). Hoisted so we can hook its live partials.
        let speech = SpeechTranscriberEngine()
        speech.onPartial = { [weak caption, weak settings] text in
            Task { @MainActor in
                guard settings?.showHUD ?? true else { return }   // caption rides with the HUD toggle
                caption?.setText(text)
            }
        }

        let coordinator = Coordinator(
            hotkey: HotkeyMonitor(config: config),
            audio: MicAudioCapture(config: config),
            transcriber: speech,
            cleaner: RoutingCleaner(config: config),   // routes to the user's chosen backend, live
            inserter: PasteInserter(config: config),
            targets: AXTargetProvider(),
            config: config
        )

        // Status fans out to the menu bar always, and to the HUD only if the user keeps it on.
        coordinator.onStatus = { [weak status, weak hud, weak caption, weak settings] s in
            status?.update(s)
            let hudOn = settings?.showHUD ?? true
            hud?.update(hudOn ? s : .idle)
            caption?.update(hudOn ? s : .idle)
            if (s == .inserted || s == .insertedRaw), settings?.soundEnabled == true {
                NSSound(named: "Tink")?.play()   // subtle confirmation when text lands
            }
        }
        // Live mic level → meter → HUD (passive tap alongside the transcriber).
        coordinator.audioMonitor = { [weak levelMeter] buffer in levelMeter?.process(buffer) }
        levelMeter.onLevel = { [weak hud] level in hud?.setLevel(level) }
        // Completed dictations go to local history.
        coordinator.onCompleted = { [weak store] result in store?.record(result) }
        // Apply the user's dictionary replacements to the final text.
        // Final text pass: dictionary replacements, then snippet expansion.
        coordinator.transform = { [weak store] text in
            guard let store else { return text }
            return store.expandSnippets(in: store.applyReplacements(to: text))
        }
        // Per-app writing style: look up the user's Styles rule for the frontmost app.
        coordinator.styleProvider = { [weak store] bundleId in store?.style(forBundleId: bundleId) }
        // Translation: the user's chosen target language (nil when off), applied during cleanup.
        coordinator.languageProvider = { [weak settings] in
            guard let lang = settings?.targetLanguage, lang != "off", !lang.isEmpty else { return nil }
            return lang
        }

        self.coordinator = coordinator
        rearm()   // first attempt to arm the hotkey (may fail until permissions are granted)

        // First run: walk the user through permissions.
        if settings.needsOnboarding {
            windowManager.showOnboarding()
        }
    }

    /// (Re)start the pipeline. Idempotent — the hotkey tap only creates once. Called at launch, when
    /// onboarding finishes, and whenever the app reactivates, so granting Input Monitoring takes
    /// effect without a manual restart.
    func rearm() {
        guard let coordinator else { return }
        do {
            try coordinator.start()
        } catch {
            Log.error("arm failed: \(error.localizedDescription)")
            status?.update(.error(error.localizedDescription))
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        rearm()
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
