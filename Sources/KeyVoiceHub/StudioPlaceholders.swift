import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Warm empty-state for a screen whose data model isn't wired yet. Keeps the shell coherent while
/// Styles and Snippets are built out.
private struct StudioComingSoon: View {
    let title: String
    let subtitle: String
    let icon: String
    let blurb: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
                    Text(subtitle).font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
                StudioCard {
                    VStack(spacing: 12) {
                        Image(systemName: icon).font(.system(size: 30, weight: .light))
                            .foregroundStyle(KeyVoiceTokens.Colors.accent)
                        Text(blurb)
                            .font(.system(size: 14)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                            .multilineTextAlignment(.center).frame(maxWidth: 360)
                        Text("Coming together in this build")
                            .font(.system(size: 11.5, weight: .bold)).tracking(0.6)
                            .foregroundStyle(KeyVoiceTokens.Colors.accent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(KeyVoiceTokens.Colors.accentSoft))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StylesView: View {
    let store: Store
    var body: some View {
        StudioComingSoon(
            title: "Styles",
            subtitle: "The same words, dressed for the room — formal in Mail, casual in Slack, verbatim in code.",
            icon: "wand.and.stars",
            blurb: "Per-app writing styles let KeyVoice match tone to the app you're typing into, using only punctuation and phrasing — never changing what you meant."
        )
    }
}

struct SnippetsView: View {
    let store: Store
    var body: some View {
        StudioComingSoon(
            title: "Snippets",
            subtitle: "Say a trigger, get the whole thing — signatures, addresses, boilerplate.",
            icon: "text.badge.plus",
            blurb: "Snippets expand a spoken phrase into text you type again and again. Say “sign off” and get your full signature."
        )
    }
}
