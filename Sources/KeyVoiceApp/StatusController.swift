import AppKit
import KeyVoiceCore

/// The menu-bar icon. Reflects pipeline state so nothing fails invisibly.
@MainActor
final class StatusController {
    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎙️"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "KeyVoice", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func update(_ status: PipelineStatus) {
        let title: String
        switch status {
        case .idle:               title = "🎙️"
        case .listening:          title = "🔴"
        case .thinking:           title = "✨"
        case .inserted:           title = "✅"
        case .insertedRaw:        title = "📝"
        case .skippedNoSpeech:    title = "🤫"
        case .abortedTargetLost:  title = "⚠️"
        case .error:              title = "❌"
        }
        item.button?.title = title
    }
}
