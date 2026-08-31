import AppKit
import KeyVoiceCore
import KeyVoiceHotkey
import KeyVoiceInsert
import KeyVoiceAudio
import KeyVoiceCleanup

/// Wires the concrete implementations into the Coordinator and owns app lifetime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: Coordinator?
    private var status: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig()
        let status = StatusController()
        self.status = status

        let coordinator = Coordinator(
            hotkey: HotkeyMonitor(config: config),
            audio: MicAudioCapture(config: config),
            transcriber: SpeechTranscriberEngine(),   // WhisperKitEngine() is the fallback
            cleaner: ClaudeCleaner(config: config),
            inserter: PasteInserter(config: config),
            targets: AXTargetProvider(),
            config: config
        )
        coordinator.onStatus = { [weak status] s in status?.update(s) }
        do {
            try coordinator.start()
        } catch {
            status.update(.error(error.localizedDescription))
        }
        self.coordinator = coordinator
    }
}
