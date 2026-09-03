import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Dictionary: custom words and replacements the user teaches KeyVoice. Studio language — the same
/// warm paper, serif, and spectrum as every other screen (it used to be on the old glass system).
struct DictionaryView: View {
    let store: Store

    @State private var entries: [DictionaryEntry] = []
    @State private var search = ""
    @State private var heard = ""
    @State private var replacement = ""

    private var filtered: [DictionaryEntry] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return entries }
        return entries.filter { $0.from.localizedCaseInsensitiveContains(q) || $0.to.localizedCaseInsensitiveContains(q) }
    }

    private var canAdd: Bool {
        !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                addCard
                searchField
                if entries.isEmpty {
                    empty("No entries yet", "Teach KeyVoice a word or phrase above.")
                } else if filtered.isEmpty {
                    empty("No matches", "Try a different search.")
                } else {
                    StudioCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(filtered) { entry in
                                DictionaryRow(entry: entry) { delete(entry) }
                                if entry.id != filtered.last?.id {
                                    Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1).padding(.horizontal, 18)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Dictionary").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Turn the words KeyVoice hears into the words you want — names, acronyms, spellings.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private var addCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                StudioSectionLabel("Add a replacement")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 12) {
                        field("Heard", "what KeyVoice heard", $heard)
                        Image(systemName: "arrow.right").foregroundStyle(KeyVoiceTokens.Colors.fog).padding(.bottom, 9)
                        field("Replace with", "preferred word or phrase", $replacement)
                        addButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        field("Heard", "what KeyVoice heard", $heard)
                        field("Replace with", "preferred word or phrase", $replacement)
                        addButton.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var addButton: some View {
        Button(action: add) {
            Text("Add").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(canAdd ? .white : KeyVoiceTokens.Colors.fog)
                .padding(.horizontal, 20).padding(.vertical, 9)
                .background(Capsule().fill(canAdd ? KeyVoiceTokens.Colors.accent : KeyVoiceTokens.Colors.paper2))
        }
        .buttonStyle(.plain).focusEffectDisabled().disabled(!canAdd)
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.4)
                .foregroundStyle(KeyVoiceTokens.Colors.fog)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain).font(.system(size: 14.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text).tint(KeyVoiceTokens.Colors.accent)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(KeyVoiceTokens.Colors.paper2))
                .onSubmit(add)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").foregroundStyle(KeyVoiceTokens.Colors.fog)
            TextField("Search replacements", text: $search)
                .textFieldStyle(.plain).font(.system(size: 14.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text).tint(KeyVoiceTokens.Colors.accent)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KeyVoiceTokens.Colors.fog)
                }.buttonStyle(.plain).focusEffectDisabled()
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Capsule().fill(KeyVoiceTokens.Colors.card).overlay(Capsule().strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)))
    }

    private func empty(_ title: String, _ subtitle: String) -> some View {
        StudioCard {
            VStack(spacing: 10) {
                Image(systemName: "character.book.closed").font(.system(size: 30, weight: .light))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                Text(title).font(.studioSerif(20)).foregroundStyle(KeyVoiceTokens.Colors.text)
                Text(subtitle).font(.system(size: 13.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
    }

    // MARK: - Data

    private func reload() { entries = store.dictionaryEntries() }

    private func add() {
        let from = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return }
        store.addDictionaryEntry(from: from, to: to)
        heard = ""; replacement = ""
        reload()
    }

    private func delete(_ entry: DictionaryEntry) { store.delete(entry); reload() }
}

/// One replacement row: heard → replacement, with a hover-revealed delete.
private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.from).font(.system(size: 15, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.text)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 11)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                    Text(entry.to).font(.system(size: 13.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
            }
            Spacer(minLength: 8)
            if entry.starred {
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(KeyVoiceTokens.Colors.accent)
            }
            // Reserve the delete button's space always; toggle only opacity so hover never reflows.
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.fog)
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .help("Delete replacement").accessibilityLabel("Delete \(entry.from)")
            .opacity(hovering ? 1 : 0)
            .allowsHitTesting(hovering)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 14)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}
