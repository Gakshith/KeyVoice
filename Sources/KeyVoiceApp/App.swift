import AppKit

/// Menu-bar app entry. `.accessory` activation policy = no Dock icon (LSUIElement).
@main
@MainActor
struct KeyVoiceMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
