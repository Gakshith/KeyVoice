import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Snippets: spoken shortcuts that expand into frequently used text.
struct SnippetsView: View {
    let store: Store

    @State private var snippets: [Snippet] = []
    @State private var trigger = ""
    @State private var expansion = ""
    @State private var showingAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if snippets.isEmpty {
                    empty
                } else {
                    HStack(alignment: .center) {
                        StudioSectionLabel("Voice shortcuts")
                        Spacer(minLength: 16)
                        addButton
                    }

                    StudioCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(snippets) { snippet in
                                snippetRow(snippet)
                                if snippet.id != snippets.last?.id {
                                    Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                                        .padding(.horizontal, 18)
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
        .sheet(isPresented: $showingAddSheet) {
            addSnippetSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Snippets").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Say a trigger, get the whole thing — signatures, addresses, boilerplate.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(snippet.trigger)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(KeyVoiceTokens.Colors.accent)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(KeyVoiceTokens.Colors.accentSoft))
                .fixedSize(horizontal: true, vertical: false)

            Text("→")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KeyVoiceTokens.Colors.fog)
                .padding(.top, 5)

            Text(snippet.expansion)
                .font(.system(size: 14.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Spacer(minLength: 8)

            Button(role: .destructive) {
                delete(snippet)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(KeyVoiceTokens.Colors.fog)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Delete snippet")
            .accessibilityLabel("Delete snippet \(snippet.trigger)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 15)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", role: .destructive) { delete(snippet) }
        }
    }

    private var addButton: some View {
        Button(action: presentAddSheet) {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                Text("Add a snippet").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(KeyVoiceTokens.Colors.paper)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(KeyVoiceTokens.Colors.velvet))
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        StudioCard {
            VStack(spacing: 11) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                Text("No snippets yet")
                    .font(.studioSerif(20))
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                Text("Turn a short spoken trigger into text you use again and again.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .multilineTextAlignment(.center)
                addButton.padding(.top, 3)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
    }

    private var addSnippetSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add a snippet")
                    .font(.studioSerif(24))
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                Text("Say the trigger and KeyVoice will insert the full expansion.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
            }

            VStack(alignment: .leading, spacing: 16) {
                snippetField("Trigger") {
                    TextField("Trigger (say this)", text: $trigger)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(KeyVoiceTokens.Colors.text)
                        .tint(KeyVoiceTokens.Colors.accent)
                }

                snippetField("Expansion") {
                    TextField("Expansion (get this)", text: $expansion, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(KeyVoiceTokens.Colors.text)
                        .tint(KeyVoiceTokens.Colors.accent)
                        .lineLimit(3...6)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { showingAddSheet = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                Button(action: saveSnippet) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Capsule().fill(KeyVoiceTokens.Colors.velvet))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
            }
        }
        .padding(26)
        .frame(width: 460)
    }

    private func snippetField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            StudioSectionLabel(label)
            content()
                .padding(.horizontal, 13).padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KeyVoiceTokens.Colors.paper2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)
                        }
                )
        }
    }

    private var canSave: Bool {
        !trimmedTrigger.isEmpty && !trimmedExpansion.isEmpty
    }

    private var trimmedTrigger: String {
        trigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedExpansion: String {
        expansion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Data

    private func reload() {
        snippets = store.snippets()
    }

    private func presentAddSheet() {
        trigger = ""
        expansion = ""
        showingAddSheet = true
    }

    private func saveSnippet() {
        guard canSave else { return }
        store.addSnippet(trigger: trimmedTrigger, expansion: trimmedExpansion)
        reload()
        showingAddSheet = false
    }

    private func delete(_ snippet: Snippet) {
        store.delete(snippet)
        reload()
    }
}
