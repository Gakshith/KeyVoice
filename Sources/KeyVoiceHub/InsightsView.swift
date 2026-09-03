import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Insights: local-only usage stats. Basic in this milestone (Codex enriches with the WPM gauge,
/// usage bars, and streak heatmap from the approved preview). The privacy counter is the anchor.
struct InsightsView: View {
    let store: Store

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                HStack(spacing: 16) {
                    StudioCard { StudioStat(value: stats.words.formatted(), label: "Words all time") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StudioCard { StudioStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StudioCard { StudioStat(value: "\(stats.streak)", unit: stats.streak == 1 ? "day" : "days", label: "Current streak") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                privacyCounter
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { stats = store.stats() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Insights").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("All computed on your Mac. Nothing tracked, nothing uploaded.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private var privacyCounter: some View {
        StudioCard {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 26))
                    .foregroundStyle(KeyVoiceTokens.Colors.good)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sent to the cloud")
                        .font(.system(size: 12, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(KeyVoiceTokens.Colors.fog)
                    Text("0 bytes")
                        .font(.studioSerif(30))
                        .foregroundStyle(KeyVoiceTokens.Colors.good)
                }
                Spacer()
                Text("Your voice is transcribed on-device and never uploaded.")
                    .font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .frame(maxWidth: 240, alignment: .trailing).multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
