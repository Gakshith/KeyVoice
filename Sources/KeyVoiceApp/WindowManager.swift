import AppKit
import SwiftUI
import KeyVoiceCore
import KeyVoiceStore
import KeyVoiceHub
import KeyVoiceOnboarding

/// Owns the app's real windows (Hub, Onboarding) and the activation-policy dance: KeyVoice runs as
/// a menu-bar `.accessory` app, but while a window is open it becomes `.regular` so the window gets
/// a dock icon, an app menu, and normal focus — then drops back to `.accessory` when the last one
/// closes. Without this, SwiftUI windows from an accessory app misbehave (no focus, no dock).
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private let store: Store
    private let settings: SettingsStore
    private let readiness: Readiness
    private let onSetAPIKey: () -> Void
    private let onRearm: () -> Void
    private let onFix: (ReadinessItem) -> Void

    private var hubWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private let hubNav = HubNavigation()

    init(store: Store, settings: SettingsStore, readiness: Readiness,
         onSetAPIKey: @escaping () -> Void, onRearm: @escaping () -> Void,
         onFix: @escaping (ReadinessItem) -> Void) {
        self.store = store
        self.settings = settings
        self.readiness = readiness
        self.onSetAPIKey = onSetAPIKey
        self.onRearm = onRearm
        self.onFix = onFix
    }

    func showHub(section: StudioSection? = nil) {
        if let section { hubNav.section = section }   // deep-link (e.g. menu bar → Settings)
        if hubWindow == nil {
            hubWindow = makeWindow(
                title: "KeyVoice",
                content: StudioShell(store: store, settings: settings, readiness: readiness, nav: hubNav,
                                     onSetAPIKey: onSetAPIKey, onFix: onFix),
                fullBleed: true
            )
        }
        present(hubWindow)
    }

    /// Open the Hub straight to Settings (menu bar → Settings…).
    func showSettings() { showHub(section: .settings) }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(
                title: "Welcome to KeyVoice",
                content: OnboardingView(settings: settings) { [weak self] in
                    self?.settings.needsOnboarding = false
                    self?.onboardingWindow?.close()
                    self?.onRearm()   // permissions likely just granted — arm the hotkey without a restart
                },
                styleMask: [.titled, .closable]
            )
        }
        present(onboardingWindow)
    }

    // MARK: - Plumbing

    private func makeWindow(
        title: String,
        content: some View,
        styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable],
        fullBleed: Bool = false
    ) -> NSWindow {
        // A full-bleed window lets the aurora backdrop run edge-to-edge under a transparent titlebar,
        // so the glass Hub reads as one continuous luminous surface instead of a framed dark box.
        let mask = fullBleed ? styleMask.union(.fullSizeContentView) : styleMask
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: mask, backing: .buffered, defer: false
        )
        window.title = title
        if fullBleed {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        } else {
            window.titlebarAppearsTransparent = false
        }
        window.isReleasedWhenClosed = false          // we keep the reference; reuse on reopen
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.delegate = self
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)          // gain dock icon + app menu while visible
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// When the last app window closes, slip back to the menu-bar-only accessory policy.
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let anyVisible = [self.hubWindow, self.onboardingWindow].contains { $0?.isVisible == true }
            if !anyVisible { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
