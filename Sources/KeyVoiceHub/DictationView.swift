import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Dictation home: a warm greeting, the living voice-spectrum hero, and a stat rail.
struct DictationView: View {
    let store: Store

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                greeting
                HStack(alignment: .top, spacing: 18) {
                    hero
                    rail.frame(width: 280)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { stats = store.stats() }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Welcome back")
                .font(.studioSerif(30))
                .foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("You've dictated \(stats.words) words. Hold Right-Option anywhere to keep going.")
                .font(.system(size: 14.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(KeyVoiceTokens.Colors.velvet)
            SpectrumWaveform(level: 0.5)
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(KeyVoiceTokens.Colors.good)
                        .frame(width: 7, height: 7)
                    Text("READY TO LISTEN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color(white: 0.72))
                }
                Text("Speak, and it lands where your cursor already is.")
                    .font(.studioSerif(27))
                    .foregroundStyle(Color(white: 0.96))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                Spacer(minLength: 18)
                HStack(spacing: 9) {
                    Text("⌥")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.96)))
                        .foregroundStyle(KeyVoiceTokens.Colors.velvet)
                    Text("Hold to talk")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.90))
                }
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(
                    Capsule().fill(Color.white.opacity(0.1))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                )
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 210)
    }

    private var rail: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 18) {
                StudioStat(value: stats.words.formatted(), label: "Words dictated")
                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                StudioStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace")
                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                StudioStat(value: "\(stats.streak)", unit: stats.streak == 1 ? "day" : "days", label: "Current streak")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
