import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// The KeyVoice Studio window: a fully custom sidebar + detail router on warm paper. We deliberately
/// drop `NavigationSplitView` — its pane materials fought the design (opaque dark chrome over the
/// backdrop). Here every surface is ours, so the look is consistent edge to edge.
public struct StudioShell: View {
    let store: Store
    let settings: SettingsStore
    let nav: HubNavigation
    let onSetAPIKey: () -> Void

    public init(store: Store, settings: SettingsStore, nav: HubNavigation, onSetAPIKey: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.nav = nav
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
        .frame(minWidth: 700, minHeight: 500)
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
                StudioNavItem(s.title, systemImage: s.icon, selected: nav.section == s) {
                    nav.section = s
                }
            }

            Spacer(minLength: 16)
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
            HStack(spacing: 0) {
                Text("Key").font(.studioSerif(19, .medium))
                Text("Voice").font(.studioSerif(19, .regular)).italic()
            }
            .foregroundStyle(KeyVoiceTokens.Colors.text)
        }
    }

    // MARK: - Detail

    @ViewBuilder private var detail: some View {
        switch nav.section {
        case .dictation:  DictationView(store: store)
        case .history:    HistoryView(store: store)
        case .dictionary: DictionaryView(store: store)
        case .styles:     StylesView(store: store)
        case .snippets:   SnippetsView(store: store)
        case .insights:   InsightsView(store: store)
        case .settings:   SettingsView(store: store, settings: settings, onSetAPIKey: onSetAPIKey)
        }
    }
}

/// Shared selection for the Hub, so the menu bar can deep-link to a section (e.g. Settings).
@MainActor
@Observable
public final class HubNavigation {
    public var section: StudioSection = .dictation
    public init() {}
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
