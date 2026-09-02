import SwiftUI
import KeyVoiceStore

/// First-run walkthrough: welcome → permission cards (Input Monitoring, Accessibility, Microphone)
/// with live status → mic test → shortcut → try-it-yourself → done.
/// Phase 0 stub — the full flow is built on the `onboarding` branch. Signature is frozen so the
/// app shell can present it now.
public struct OnboardingView: View {
    let settings: SettingsStore
    let onFinish: () -> Void

    public init(settings: SettingsStore, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Welcome to KeyVoice")
                .font(.title.weight(.semibold))
            Text("The permission walkthrough will appear here.")
                .foregroundStyle(.secondary)
            Button("Finish", action: onFinish)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 6)
        }
        .padding(40)
        .frame(width: 520, height: 420)
    }
}
