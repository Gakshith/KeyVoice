import SwiftUI
import KeyVoiceStore

/// Settings: hotkey, microphone, API key, launch-at-login, data.
/// Phase 0 stub — the full screen is built on the `settings` branch. Signature is frozen.
struct SettingsView: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title2.weight(.semibold))
            Text("Hotkey, microphone, API key, and more will live here.")
                .foregroundStyle(.secondary)
            Button("Set API Key…", action: onSetAPIKey)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }
}
