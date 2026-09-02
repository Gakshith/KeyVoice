import SwiftUI
import KeyVoiceStore

/// First-run walkthrough: welcome → permission cards (Input Monitoring, Accessibility, Microphone)
/// with live status → done. The window can't do anything useful until the three macOS permissions
/// are granted, so this is the app's front door on first launch.
///
/// Signature is frozen so the app shell can present it: `OnboardingView(settings:onFinish:)`.
public struct OnboardingView: View {
    let settings: SettingsStore
    let onFinish: () -> Void

    public init(settings: SettingsStore, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
    }

    /// The three panels of the flow. Raw values give us Back/Continue arithmetic for free.
    private enum Step: Int, CaseIterable {
        case welcome, permissions, done
    }

    @State private var step: Step = .welcome
    @State private var checker = PermissionChecker()

    /// Drives the live-status polling on the permissions step. macOS never calls back when a
    /// permission flips in System Settings, so we re-read on a timer while that step is on screen.
    private let pollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

            Divider()
            bottomBar
        }
        .frame(width: 520, height: 460)
        .onReceive(pollTimer) { _ in
            // Only worth polling while the user is looking at the cards.
            if step == .permissions { checker.refresh() }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:     welcomeStep
        case .permissions: permissionsStep
        case .done:        doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.primary)
            Text("Welcome to KeyVoice")
                .font(.title.weight(.semibold))
            Text("Hold **Right-Option** and talk. Let go, and your words appear as text in any app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Text("First, three quick macOS permissions.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(40)
    }

    private var permissionsStep: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Grant three permissions")
                    .font(.title2.weight(.semibold))
                Text("Flip each one on in System Settings — this window updates as you go.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(Permission.allCases, id: \.self) { permission in
                    PermissionCard(
                        permission: permission,
                        granted: checker.isGranted(permission),
                        action: { checker.requestAccess(for: permission) }
                    )
                }
            }

            if checker.allGranted {
                Label("All set — you're ready to go.", systemImage: "checkmark.seal.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .animation(.easeInOut(duration: 0.2), value: checker.allGranted)
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: checker.allGranted ? "checkmark.circle" : "mic.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(checker.allGranted ? AnyShapeStyle(.green) : AnyShapeStyle(.primary))
            Text("You're all set")
                .font(.title.weight(.semibold))
            Text("Hold **Right-Option** and speak. KeyVoice lives in your menu bar.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !checker.allGranted {
                Label("Some permissions are still off — dictation may not work until they're on.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.top, 4)
            }
        }
        .padding(40)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            if step != .welcome {
                Button("Back") { goBack() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            StepDots(current: step.rawValue, total: Step.allCases.count)
                .frame(maxWidth: .infinity)

            switch step {
            case .welcome, .permissions:
                Button(step == .permissions && !checker.allGranted ? "Continue anyway" : "Continue") {
                    goNext()
                }
                .keyboardShortcut(.defaultAction)
            case .done:
                Button("Finish") {
                    settings.needsOnboarding = false
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func goNext() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }
}

// MARK: - Permission card

/// One row of the permissions step: icon, title + why, a live status dot, and an action button.
private struct PermissionCard: View {
    let permission: Permission
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: permission.symbol)
                .font(.system(size: 20, weight: .regular))
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(permission.title)
                        .font(.headline)
                    StatusDot(granted: granted)
                }
                Text(permission.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if granted {
                Text("Granted")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("Enable", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(granted ? AnyShapeStyle(.green.opacity(0.4)) : AnyShapeStyle(.clear), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: granted)
    }
}

/// Green when granted, muted grey otherwise. The one thing the eye tracks while granting.
private struct StatusDot: View {
    let granted: Bool

    var body: some View {
        Circle()
            .fill(granted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary.opacity(0.4)))
            .frame(width: 8, height: 8)
            .accessibilityLabel(granted ? "Granted" : "Not granted")
    }
}

/// Little progress pips in the bottom bar so the user knows how far along they are.
private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.3)))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
