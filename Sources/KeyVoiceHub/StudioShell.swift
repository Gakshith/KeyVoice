import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// The KeyVoice Studio window: a fully custom sidebar + detail router on warm paper. We deliberately
/// drop `NavigationSplitView` — its pane materials fought the design (opaque dark chrome over the
/// backdrop). Here every surface is ours, so the look is consistent edge to edge.
public struct StudioShell: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

    @State private var section: StudioSection = .dictation

    public init(store: Store, settings: SettingsStore, onSetAPIKey: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onSetAPIKey = onSetAPIKey
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 232)
                .background(KeyVoiceTokens.Colors.paper)
            Rectangle()
                .fill(KeyVoiceTokens.Colors.line)
                .frame(width: 1)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KeyVoiceTokens.Colors.paper)
        }
        .frame(minWidth: 920, minHeight: 640)
        .background(KeyVoiceTokens.Colors.paper)
        .environment(\.colorScheme, .light)   // committed warm-light world
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            brand
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            StudioSectionLabel("Studio")
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            ForEach(StudioSection.allCases) { s in
                StudioNavItem(s.title, systemImage: s.icon, selected: section == s) {
                    section = s
                }
            }

            Spacer(minLength: 16)
            privacyCard
        }
        .padding(.horizontal, 12)
        .padding(.top, 46)          // clear the traffic lights
        .padding(.bottom, 16)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(KeyVoiceTokens.Colors.velvet)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KeyVoiceTokens.Colors.paper)
                }
            (Text("Key").font(.studioSerif(19, .medium)) + Text("Voice").font(.studioSerif(19, .regular)).italic())
                .foregroundStyle(KeyVoiceTokens.Colors.text)
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No account. No cloud.")
                .font(.studioSerif(17))
                .foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Transcribed on this Mac. Unlimited words, forever.")
                .font(.system(size: 12))
                .foregroundStyle(KeyVoiceTokens.Colors.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KeyVoiceTokens.Colors.accentSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(KeyVoiceTokens.Colors.accent.opacity(0.18), lineWidth: 1)
                }
        }
    }

    // MARK: - Detail

    @ViewBuilder private var detail: some View {
        switch section {
        case .dictation:  DictationView(store: store)
        case .history:    HistoryView(store: store)
        case .dictionary: DictionaryView(store: store)
        case .styles:     StylesView()
        case .snippets:   SnippetsView()
        case .insights:   InsightsView(store: store)
        case .settings:   SettingsView(store: store, settings: settings, onSetAPIKey: onSetAPIKey)
        }
    }
}

/// The Studio sidebar sections, in order.
public enum StudioSection: String, CaseIterable, Identifiable {
    case dictation, history, dictionary, styles, snippets, insights, settings
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: "Dictation"
        case .history: "History"
        case .dictionary: "Dictionary"
        case .styles: "Styles"
        case .snippets: "Snippets"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dictation: "mic"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .styles: "wand.and.stars"
        case .snippets: "text.badge.plus"
        case .insights: "chart.bar"
        case .settings: "gearshape"
        }
    }
}
