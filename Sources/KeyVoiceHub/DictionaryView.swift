import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Dictionary: custom words and replacements the user teaches KeyVoice.
struct DictionaryView: View {
    let store: Store

    @State private var entries: [DictionaryEntry] = []
    @State private var searchText = ""
    @State private var heardText = ""
    @State private var replacementText = ""

    private var filteredEntries: [DictionaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }

        return entries.filter { entry in
            entry.from.localizedCaseInsensitiveContains(query)
                || entry.to.localizedCaseInsensitiveContains(query)
        }
    }

    private var canAdd: Bool {
        !heardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.l) {
            VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.xs) {
                Text("Dictionary")
                    .font(KeyVoiceTokens.Typography.title)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink)
                Text("Teach KeyVoice how to turn the words it hears into the words you want.")
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.68))
            }

            HStack(spacing: KeyVoiceTokens.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.58))
                TextField("Search heard text or replacements", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, KeyVoiceTokens.Spacing.m)
            .padding(.vertical, KeyVoiceTokens.Spacing.s)
            .glassSurface(
                shape: RoundedRectangle(
                    cornerRadius: KeyVoiceTokens.Radius.small,
                    style: .continuous
                )
            )

            GlassCard {
                VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.m) {
                    Label("Add replacement", systemImage: "plus")
                        .font(KeyVoiceTokens.Typography.headline)
                        .foregroundStyle(KeyVoiceTokens.Colors.ink)
                        .symbolRenderingMode(.monochrome)
                        .tint(KeyVoiceTokens.Colors.ice)

                    HStack(alignment: .bottom, spacing: KeyVoiceTokens.Spacing.m) {
                        dictionaryField(
                            label: "Heard",
                            placeholder: "What KeyVoice heard",
                            text: $heardText
                        )

                        Image(systemName: "arrow.right")
                            .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.5))
                            .padding(.bottom, KeyVoiceTokens.Spacing.s)

                        dictionaryField(
                            label: "Replace with",
                            placeholder: "Preferred word or phrase",
                            text: $replacementText
                        )

                        Button(action: addEntry) {
                            Text("Add")
                                .font(KeyVoiceTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(.black.opacity(0.82))
                                .padding(.horizontal, KeyVoiceTokens.Spacing.l)
                                .padding(.vertical, KeyVoiceTokens.Spacing.s)
                                .background(
                                    canAdd
                                        ? KeyVoiceTokens.Colors.ice
                                        : KeyVoiceTokens.Colors.ice.opacity(0.36),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                        .accessibilityHint("Adds this replacement to the dictionary")
                    }
                }
            }

            Group {
                if entries.isEmpty {
                    GlassPanel {
                        ContentUnavailableView(
                            "No Dictionary Entries",
                            systemImage: "character.book.closed",
                            description: Text("Add a replacement above to teach KeyVoice a word or phrase.")
                        )
                        .foregroundStyle(KeyVoiceTokens.Colors.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if filteredEntries.isEmpty {
                    GlassPanel {
                        ContentUnavailableView.search(text: searchText)
                            .foregroundStyle(KeyVoiceTokens.Colors.ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.s) {
                        SectionHeader("Replacements")
                            .padding(.horizontal, KeyVoiceTokens.Spacing.xs)

                        ScrollView {
                            LazyVStack(spacing: KeyVoiceTokens.Spacing.s) {
                                ForEach(filteredEntries) { entry in
                                    DictionaryEntryRow(entry: entry) {
                                        delete(entry)
                                    }
                                }
                            }
                            .padding(.vertical, KeyVoiceTokens.Spacing.xs)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(KeyVoiceTokens.Spacing.xl)
        .navigationTitle("Dictionary")
        .onAppear(perform: reload)
    }

    private func dictionaryField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.s) {
            SectionHeader(label)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(KeyVoiceTokens.Typography.body)
                .foregroundStyle(KeyVoiceTokens.Colors.ink)
                .padding(.horizontal, KeyVoiceTokens.Spacing.m)
                .padding(.vertical, KeyVoiceTokens.Spacing.s)
                .background(
                    KeyVoiceTokens.Colors.glassGround,
                    in: RoundedRectangle(
                        cornerRadius: KeyVoiceTokens.Radius.small,
                        style: .continuous
                    )
                )
                .onSubmit(addEntry)
        }
        .frame(maxWidth: .infinity)
    }

    private func addEntry() {
        let from = heardText.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return }

        store.addDictionaryEntry(from: from, to: to)
        heardText = ""
        replacementText = ""
        reload()
    }

    private func delete(_ entry: DictionaryEntry) {
        store.delete(entry)
        reload()
    }

    private func reload() {
        entries = store.dictionaryEntries()
    }
}

private struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        GlassRow {
            VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.xs) {
                Text(entry.from)
                    .font(KeyVoiceTokens.Typography.body.weight(.medium))
                    .foregroundStyle(KeyVoiceTokens.Colors.ink)
                Text(entry.to)
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.64))
            }
        } trailing: {
            HStack(spacing: KeyVoiceTokens.Spacing.m) {
                if entry.starred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(KeyVoiceTokens.Colors.ice)
                        .accessibilityLabel("Starred")
                }

                if hovering {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.62))
                    }
                    .buttonStyle(.plain)
                    .help("Delete replacement")
                    .accessibilityLabel("Delete \(entry.from)")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            withAnimation(KeyVoiceTokens.Motion.quick) {
                hovering = isHovering
            }
        }
    }
}
