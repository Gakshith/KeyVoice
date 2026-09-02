import SwiftUI
import KeyVoiceStore

/// Dictionary: custom words and replacements the user teaches KeyVoice.
/// Phase 0 stub — the full screen is built on the `dictionary` branch. Signature is frozen.
struct DictionaryView: View {
    let store: Store

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Dictionary")
                .font(.title2.weight(.semibold))
            Text("Teach KeyVoice your names, acronyms, and replacements here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Dictionary")
    }
}
