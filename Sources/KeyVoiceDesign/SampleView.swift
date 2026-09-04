import SwiftUI

/// A compact visual smoke test for the KeyVoice frozen-glass component kit.
public struct KeyVoiceDesignSampleView: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.20),
                    Color(red: 0.17, green: 0.26, blue: 0.36),
                    KeyVoiceTokens.Colors.ice.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.l) {
                    Text("KeyVoice")
                        .font(KeyVoiceTokens.Typography.title)
                        .foregroundStyle(.white)

                    SectionHeader("Today")
                        .foregroundStyle(.white.opacity(0.72))

                    HStack(spacing: KeyVoiceTokens.Spacing.m) {
                        StatTile(title: "Words", value: "1,284")
                        StatTile(title: "Sessions", value: "18")
                        StatTile(title: "Minutes saved", value: "42")
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.s) {
                            Text("Ready to dictate")
                                .font(KeyVoiceTokens.Typography.headline)
                            Text("Hold your shortcut and speak naturally.")
                                .font(KeyVoiceTokens.Typography.body)
                                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.68))
                        }
                    }

                    GlassCard {
                        GlassRow {
                            Label("Vocabulary sync", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(KeyVoiceTokens.Colors.ice)
                        } trailing: {
                            Text("Up to date")
                                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.62))
                        }
                    }
                }
                .padding(KeyVoiceTokens.Spacing.xl)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

#Preview("KeyVoice Design System") {
    KeyVoiceDesignSampleView()
        .frame(width: 820, height: 600)
}
