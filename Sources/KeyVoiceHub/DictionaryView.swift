import SwiftUI
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dictionary")
                    .font(.largeTitle.weight(.semibold))
                Text("Teach KeyVoice how to turn the words it hears into the words you want.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search heard text or replacements", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.separator, lineWidth: 1)
            }

            GroupBox {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What KeyVoice heard", text: $heardText)
                            .onSubmit(addEntry)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Replace with")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Preferred word or phrase", text: $replacementText)
                            .onSubmit(addEntry)
                    }

                    Button("Add", action: addEntry)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdd)
                }
                .padding(4)
            } label: {
                Label("Add replacement", systemImage: "plus")
                    .font(.headline)
            }

            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Dictionary Entries",
                        systemImage: "character.book.closed",
                        description: Text("Add a replacement above to teach KeyVoice a word or phrase.")
                    )
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredEntries) { entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.from)
                                    .font(.body.weight(.medium))
                                Text(entry.to)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 16)

                            if entry.starred {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Starred")
                            }

                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete replacement")
                            .accessibilityLabel("Delete \(entry.from)")
                        }
                        .padding(.vertical, 5)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .navigationTitle("Dictionary")
        .onAppear(perform: reload)
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
