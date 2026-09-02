import AppKit
import SwiftUI
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
    private let onSetAPIKey: () -> Void

    private var hubWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(store: Store, settings: SettingsStore, onSetAPIKey: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onSetAPIKey = onSetAPIKey
    }

    func showHub() {
        if hubWindow == nil {
            hubWindow = makeWindow(
                title: "KeyVoice",
                content: HubView(store: store, settings: settings, onSetAPIKey: onSetAPIKey)
            )
        }
        present(hubWindow)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(
                title: "Welcome to KeyVoice",
                content: OnboardingView(settings: settings) { [weak self] in
                    self?.settings.needsOnboarding = false
                    self?.onboardingWindow?.close()
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
        styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: styleMask, backing: .buffered, defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = false
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
