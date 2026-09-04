import SwiftUI
import AppKit
import KeyVoiceDesign
import KeyVoiceStore

/// Styles: per-app writing rules that adapt KeyVoice's tone to the current room.
struct StylesView: View {
    let store: Store

    @State private var rules: [StyleRule] = []
    @State private var runningApps: [RunningApp] = []
    @State private var selectedBundleId = ""
    @State private var selectedKind = StyleKind.clean.rawValue
    @State private var showingAddSheet = false

    // Adaptive: two-up when there's room, collapsing to a single column
    // as the window narrows.
    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if rules.isEmpty {
                    empty
                } else {
                    HStack(alignment: .center) {
                        StudioSectionLabel("Per-app styles")
                        Spacer(minLength: 16)
                        addButton
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(rules) { rule in
                            styleCard(rule)
                        }
                    }
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAddSheet) {
            addStyleSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Styles").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("The same words, dressed for the room — KeyVoice matches tone to the app you're typing into.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private func styleCard(_ rule: StyleRule) -> some View {
        let kind = StyleKind(rawValue: rule.kind) ?? .clean

        return StudioCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.appName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KeyVoiceTokens.Colors.text)
                            .lineLimit(1)
                        Text(kind.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(KeyVoiceTokens.Colors.fog)
                    }
                    Spacer(minLength: 8)
                    Button(role: .destructive) {
                        delete(rule)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(KeyVoiceTokens.Colors.fog)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Delete style for \(rule.appName)")
                    .accessibilityLabel("Delete style for \(rule.appName)")
                }

                Text(kind.example)
                    .font(.system(size: 12.5))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)

                HStack(spacing: 10) {
                    Text("Writing style")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    Spacer(minLength: 8)
                    Menu {
                        ForEach(StyleKind.allCases) { option in
                            Button {
                                update(rule, to: option)
                            } label: {
                                if option == kind {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(kind.title)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(KeyVoiceTokens.Colors.accent)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(Capsule().fill(KeyVoiceTokens.Colors.accentSoft))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .tint(KeyVoiceTokens.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        }
    }

    private var addButton: some View {
        Button(action: presentAddSheet) {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                Text("Add a style for an app").font(.system(size: 13, weight: .semibold))
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
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                Text("No per-app styles yet")
                    .font(.studioSerif(20))
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                Text("Choose an app and KeyVoice will match its writing style whenever you dictate there.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .multilineTextAlignment(.center)
                addButton.padding(.top, 3)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
    }

    private var addStyleSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add an app style")
                    .font(.studioSerif(24))
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                Text("Choose a running app and the tone KeyVoice should use there.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
            }

            VStack(alignment: .leading, spacing: 16) {
                sheetField("App") {
                    Picker("App", selection: $selectedBundleId) {
                        if runningApps.isEmpty {
                            Text("No running apps found").tag("")
                        } else {
                            ForEach(runningApps) { app in
                                Text(app.name).tag(app.bundleIdentifier)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tint(KeyVoiceTokens.Colors.accent)
                }

                sheetField("Writing style") {
                    Picker("Writing style", selection: $selectedKind) {
                        ForEach(StyleKind.allCases) { kind in
                            Text(kind.title).tag(kind.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tint(KeyVoiceTokens.Colors.accent)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { showingAddSheet = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                Button(action: saveStyle) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Capsule().fill(KeyVoiceTokens.Colors.velvet))
                }
                .buttonStyle(.plain)
                .disabled(selectedBundleId.isEmpty)
                .opacity(selectedBundleId.isEmpty ? 0.45 : 1)
            }
        }
        .padding(26)
        .frame(width: 430)
    }

    private func sheetField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            StudioSectionLabel(label)
            content()
                .padding(.horizontal, 12).padding(.vertical, 8)
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

    // MARK: - Data

    private func reload() {
        rules = store.styleRules()
    }

    private func presentAddSheet() {
        runningApps = availableRunningApps()
        selectedBundleId = runningApps.first?.bundleIdentifier ?? ""
        selectedKind = StyleKind.clean.rawValue
        showingAddSheet = true
    }

    private func saveStyle() {
        guard let app = runningApps.first(where: { $0.bundleIdentifier == selectedBundleId }) else { return }
        store.addStyleRule(appBundleId: app.bundleIdentifier, appName: app.name, kind: selectedKind)
        reload()
        showingAddSheet = false
    }

    private func update(_ rule: StyleRule, to kind: StyleKind) {
        guard rule.kind != kind.rawValue else { return }
        store.addStyleRule(appBundleId: rule.appBundleId, appName: rule.appName, kind: kind.rawValue)
        reload()
    }

    private func delete(_ rule: StyleRule) {
        store.delete(rule)
        reload()
    }

    private func availableRunningApps() -> [RunningApp] {
        var appsByBundleId: [String: RunningApp] = [:]

        for application in NSWorkspace.shared.runningApplications
        where application.activationPolicy == .regular {
            guard let bundleIdentifier = application.bundleIdentifier,
                  let name = application.localizedName else { continue }
            appsByBundleId[bundleIdentifier] = RunningApp(bundleIdentifier: bundleIdentifier, name: name)
        }

        return appsByBundleId.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

private enum StyleKind: String, CaseIterable, Identifiable {
    case formal
    case casual
    case code
    case clean
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formal: "Formal"
        case .casual: "Casual"
        case .code: "Code-aware"
        case .clean: "Clean"
        case .raw: "Verbatim"
        }
    }

    var example: String {
        switch self {
        case .formal: "can you review this → Could you review this?"
        case .casual: "please let me know → Let me know!"
        case .code: "user underscore id → user_id"
        case .clean: "um send it today → Send it today."
        case .raw: "Every word lands exactly as spoken."
        }
    }
}

private struct RunningApp: Identifiable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}
