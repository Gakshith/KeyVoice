import SwiftUI
import AppKit
import KeyVoiceCore
import KeyVoiceDesign
import KeyVoiceStore

/// Dictation home — a cockpit, not a poster. Top to bottom it answers: is KeyVoice ready right now?
/// (status strip + repair cards, from the real `Readiness` — never a hard-coded green light), what
/// can I do (the hero + quick actions), and what did I just say (recent dictations).
struct DictationView: View {
    let store: Store
    let settings: SettingsStore
    let readiness: Readiness
    let onFix: (ReadinessItem) -> Void
    let onNavigate: (StudioSection) -> Void

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)
    @State private var recent: [TranscriptRecord] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greeting
                statusStrip
                if !readiness.missing.isEmpty { repairCards }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        hero.frame(minWidth: 320)
                        rail.frame(width: 260)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        rail.frame(maxWidth: .infinity)
                    }
                }
                recentSection
                quickActions
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Welcome back").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("You've dictated \(stats.words) words. Hold \(hotkeyName) anywhere to keep going.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    // MARK: - Status strip (the truth)

    private var statusStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { statusPills }
            VStack(alignment: .leading, spacing: 10) { HStack(spacing: 10) { statusPills } }
        }
    }

    @ViewBuilder private var statusPills: some View {
        if readiness.isReady {
            pill(dot: KeyVoiceTokens.Colors.good, "Ready to listen", KeyVoiceTokens.Colors.text)
        } else {
            pill(dot: KeyVoiceTokens.Colors.s4, "Needs setup", KeyVoiceTokens.Colors.text)
        }
        pill(icon: "wand.and.stars", "Cleanup: \(providerName)", KeyVoiceTokens.Colors.text2)
        pill(icon: "keyboard", hotkeyName, KeyVoiceTokens.Colors.text2)
    }

    private func pill(dot: Color? = nil, icon: String? = nil, _ text: String, _ fg: Color) -> some View {
        HStack(spacing: 7) {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.fog) }
            Text(text).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(fg)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(KeyVoiceTokens.Colors.card).overlay(Capsule().strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)))
    }

    // MARK: - Repair cards

    private var repairCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudioSectionLabel("Finish setup to start dictating")
            ForEach(readiness.missing) { item in
                StudioCard(padding: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: item.symbol).font(.system(size: 18))
                            .foregroundStyle(KeyVoiceTokens.Colors.accent).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text)
                            Text(item.detail).font(.system(size: 12.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                        }
                        Spacer(minLength: 8)
                        Button(action: { onFix(item) }) {
                            Text(item.settingsAnchor == nil ? "Check again" : "Open Settings")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(KeyVoiceTokens.Colors.accent))
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(KeyVoiceTokens.Colors.velvet)
            SpectrumWaveform(level: 0.5).opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(readiness.isReady ? KeyVoiceTokens.Colors.good : KeyVoiceTokens.Colors.s4).frame(width: 7, height: 7)
                    Text(readiness.isReady ? "READY TO LISTEN" : "NOT READY YET")
                        .font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(Color(white: 0.72))
                }
                Text("Speak, and it lands where your cursor already is.")
                    .font(.studioSerif(27)).foregroundStyle(Color(white: 0.96))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
                Spacer(minLength: 18)
                HStack(spacing: 9) {
                    Text("⌥").font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.96)))
                        .foregroundStyle(KeyVoiceTokens.Colors.velvet)
                    Text("Hold \(hotkeyName) to talk").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.90))
                }
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.1)).overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)))
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 210)
    }

    private var rail: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 18) {
                StudioStat(value: stats.words.formatted(), label: "Words dictated")
                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                StudioStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace")
                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                StudioStat(value: "\(stats.streak)", unit: stats.streak == 1 ? "day" : "days", label: "Current streak")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StudioSectionLabel("Recent")
                Spacer()
                if !recent.isEmpty {
                    Button("See all") { onNavigate(.history) }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.accent)
                }
            }
            if recent.isEmpty {
                StudioCard {
                    HStack(spacing: 12) {
                        Image(systemName: "text.viewfinder").font(.system(size: 20)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                        Text("Nothing yet — hold \(hotkeyName) and speak, and it shows up here.")
                            .font(.system(size: 13.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                        Spacer()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                StudioCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(recent) { r in
                            RecentRow(record: r)
                            if r.id != recent.last?.id {
                                Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1).padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudioSectionLabel("Quick actions")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actionChips }
                VStack(spacing: 10) { actionChips }
            }
        }
    }

    @ViewBuilder private var actionChips: some View {
        actionChip("Set cleanup", "wand.and.stars") { onNavigate(.settings) }
        actionChip("Add a snippet", "text.badge.plus") { onNavigate(.snippets) }
        actionChip("Teach a word", "character.book.closed") { onNavigate(.dictionary) }
        actionChip("View history", "clock.arrow.circlepath") { onNavigate(.history) }
    }

    private func actionChip(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.accent)
                Text(title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(KeyVoiceTokens.Colors.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)))
        }
        .buttonStyle(.plain).focusEffectDisabled().frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private var hotkeyName: String { settings.hotKeyCode == 58 ? "Left-Option" : "Right-Option" }
    private var providerName: String {
        switch settings.cleanupProvider {
        case "ollama": return "Ollama"
        case "claude": return "Claude"
        default:       return "Off"
        }
    }

    private func reload() {
        stats = store.stats()
        recent = Array(store.transcripts().prefix(4))
    }
}

/// A compact recent-dictation row with a one-click copy.
private struct RecentRow: View {
    let record: TranscriptRecord
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.text).font(.system(size: 14)).foregroundStyle(KeyVoiceTokens.Colors.text)
                    .lineLimit(1).truncationMode(.tail)
                Text("\(record.appName) · \(record.wordCount) word\(record.wordCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.fog)
            }
            Spacer(minLength: 8)
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 13))
                    .foregroundStyle(copied ? KeyVoiceTokens.Colors.good : KeyVoiceTokens.Colors.fog)
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .help(copied ? "Copied" : "Copy").accessibilityLabel("Copy transcript")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        withAnimation(.easeOut(duration: 0.12)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) { copied = false }
        }
    }
}
