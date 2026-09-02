import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// The Hub window: a sidebar (Home / Dictionary / Settings) with a detail pane. This shell is the
/// frozen seam — the three screens live in their own files so they can be built in parallel.
public struct HubView: View {
    let store: Store
    let settings: SettingsStore
    let onSetAPIKey: () -> Void

    @State private var section: HubSection? = .home

    public init(store: Store, settings: SettingsStore, onSetAPIKey: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onSetAPIKey = onSetAPIKey
    }

    public var body: some View {
        NavigationSplitView {
            List(HubSection.allCases, id: \.self, selection: $section) { s in
                Label(s.title, systemImage: s.icon).tag(Optional(s))
            }
            .scrollContentBackground(.hidden)            // let the aurora show through the sidebar
            .background { GlassBackdrop() }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .navigationTitle("KeyVoice")
        } detail: {
            ZStack {
                GlassBackdrop()                          // the luminous surface every glass panel refracts
                Group {
                    switch section ?? .home {
                    case .home:       HomeView(store: store)
                    case .dictionary: DictionaryView(store: store)
                    case .settings:   SettingsView(store: store, settings: settings, onSetAPIKey: onSetAPIKey)
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)   // let the aurora run under the titlebar strip
        .frame(minWidth: 760, minHeight: 500)
    }
}

enum HubSection: CaseIterable {
    case home, dictionary, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .dictionary: "Dictionary"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .settings: "gearshape"
        }
    }
}
