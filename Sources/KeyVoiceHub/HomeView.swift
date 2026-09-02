import SwiftUI
import KeyVoiceStore

/// Home: dictation history grouped by day, search, and a stats card.
/// Phase 0 stub — the full screen is built on the `home` branch. Signature is frozen.
struct HomeView: View {
    let store: Store

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Home")
                .font(.title2.weight(.semibold))
            Text("Your dictation history and stats will appear here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Home")
    }
}
