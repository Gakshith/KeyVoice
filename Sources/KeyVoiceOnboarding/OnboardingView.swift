import SwiftUI
import KeyVoiceStore
import KeyVoiceDesign

/// First-run walkthrough: welcome → permission cards (Input Monitoring, Accessibility, Microphone)
/// with live status → a live mic test → done. The window can't do anything useful until the three
/// macOS permissions are granted, so this is the app's front door on first launch.
///
/// Re-skinned onto the KeyVoice frozen-glass language: glass permission cards, ice/amber accents,
/// KeyVoiceTokens for spacing/type, and KeyVoiceTokens.Motion springs for transitions.
///
/// Signature is frozen so the app shell can present it: `OnboardingView(settings:onFinish:)`.
public struct OnboardingView: View {
    let settings: SettingsStore
    let onFinish: () -> Void

    public init(settings: SettingsStore, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
    }

    /// The four panels of the flow. Raw values give us Back/Continue arithmetic for free.
    private enum Step: Int, CaseIterable {
        case welcome, permissions, micTest, done
    }

    @State private var step: Step = .welcome
    @State private var checker = PermissionChecker()

    /// Drives the live-status polling on the permissions/mic steps. macOS never calls back when a
    /// permission flips in System Settings, so we re-read on a timer while those steps are on screen.
    private let pollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

            Divider()
                .overlay(KeyVoiceTokens.Colors.glassStroke)
            bottomBar
        }
        .frame(width: 520, height: 460)
        .background(backdrop)
        .onReceive(pollTimer) { _ in
            // Only worth polling while a permission-sensitive step is on screen.
            if step == .permissions || step == .micTest { checker.refresh() }
        }
        .animation(KeyVoiceTokens.Motion.spring, value: step)
    }

    /// A faint ice wash so the glass cards have something cool to sit against, light or dark.
    private var backdrop: some View {
        LinearGradient(
            colors: [
                KeyVoiceTokens.Colors.ice.opacity(0.10),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:     welcomeStep
        case .permissions: permissionsStep
        case .micTest:     MicTestStep(granted: checker.microphoneGranted) {
                               checker.requestAccess(for: .microphone)
                           }
        case .done:        doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: KeyVoiceTokens.Spacing.l) {
            iceIcon("mic.circle")

            Text("Welcome to KeyVoice")
                .font(KeyVoiceTokens.Typography.title)
                .foregroundStyle(KeyVoiceTokens.Colors.ink)

            Text("Hold **Right-Option** and talk. Let go, and your words appear as text in any app.")
                .font(KeyVoiceTokens.Typography.body)
                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text("First, three quick macOS permissions.")
                .font(KeyVoiceTokens.Typography.caption)
                .tracking(0.6)
                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.5))
                .padding(.top, KeyVoiceTokens.Spacing.xs)
        }
        .padding(KeyVoiceTokens.Spacing.xl)
    }

    private var permissionsStep: some View {
        VStack(spacing: KeyVoiceTokens.Spacing.m) {
            VStack(spacing: KeyVoiceTokens.Spacing.xs) {
                Text("Grant three permissions")
                    .font(KeyVoiceTokens.Typography.headline)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink)
                Text("Flip each one on in System Settings — this window updates as you go.")
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, KeyVoiceTokens.Spacing.xs)

            VStack(spacing: KeyVoiceTokens.Spacing.s) {
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
                    .font(KeyVoiceTokens.Typography.body.weight(.medium))
                    .foregroundStyle(KeyVoiceTokens.Colors.ice)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, KeyVoiceTokens.Spacing.xl)
        .padding(.vertical, KeyVoiceTokens.Spacing.l)
        .animation(KeyVoiceTokens.Motion.spring, value: checker.allGranted)
    }

    private var doneStep: some View {
        VStack(spacing: KeyVoiceTokens.Spacing.l) {
            iceIcon(checker.allGranted ? "checkmark.circle" : "mic.circle",
                    tint: checker.allGranted ? KeyVoiceTokens.Colors.ice : KeyVoiceTokens.Colors.ink)

            Text("You're all set")
                .font(KeyVoiceTokens.Typography.title)
                .foregroundStyle(KeyVoiceTokens.Colors.ink)

            Text("Hold **Right-Option** and speak. KeyVoice lives in your menu bar.")
                .font(KeyVoiceTokens.Typography.body)
                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !checker.allGranted {
                Label("Some permissions are still off — dictation may not work until they're on.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(KeyVoiceTokens.Typography.caption)
                    .foregroundStyle(KeyVoiceTokens.Colors.amber)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.top, KeyVoiceTokens.Spacing.xs)
            }
        }
        .padding(KeyVoiceTokens.Spacing.xl)
    }

    /// A large glyph seated in a soft ice glass disc — the recurring hero mark across steps.
    private func iceIcon(_ symbol: String, tint: Color = KeyVoiceTokens.Colors.ice) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 52, weight: .light))
            .foregroundStyle(tint)
            .frame(width: 96, height: 96)
            .glassSurface(shape: Circle())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            if step != .welcome {
                Button("Back") { goBack() }
                    .buttonStyle(.plain)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.6))
            }

            StepDots(current: step.rawValue, total: Step.allCases.count)
                .frame(maxWidth: .infinity)

            switch step {
            case .welcome, .permissions, .micTest:
                Button(step == .permissions && !checker.allGranted ? "Continue anyway" : "Continue") {
                    goNext()
                }
                .tint(KeyVoiceTokens.Colors.ice)
                .keyboardShortcut(.defaultAction)
            case .done:
                Button("Finish") {
                    settings.needsOnboarding = false
                    onFinish()
                }
                .tint(KeyVoiceTokens.Colors.ice)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, KeyVoiceTokens.Spacing.l)
        .padding(.vertical, KeyVoiceTokens.Spacing.m)
    }

    private func goNext() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }
}

// MARK: - Mic test step

/// The first time KeyVoice hears you. Taps the mic while on screen and drives a glowing ice orb
/// off a smoothed input level, so the user gets immediate proof the app can hear them. The engine
/// starts in `onAppear` and — critically — stops in `onDisappear`, so the mic never outlives the step.
private struct MicTestStep: View {
    /// Whether microphone permission is currently granted. When false we show a gentle prompt
    /// instead of the meter and never start the engine.
    let granted: Bool
    /// Ask for microphone access (in-app prompt, or System Settings if already denied).
    let requestAccess: () -> Void

    @State private var monitor = MicLevelMonitor()

    var body: some View {
        VStack(spacing: KeyVoiceTokens.Spacing.l) {
            Text("Let's hear you")
                .font(KeyVoiceTokens.Typography.headline)
                .foregroundStyle(KeyVoiceTokens.Colors.ink)

            if granted {
                MicOrb(level: monitor.level)
                    .frame(width: 180, height: 180)

                Text("Say something — KeyVoice is listening.")
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                micPrompt
            }
        }
        .padding(KeyVoiceTokens.Spacing.xl)
        .animation(KeyVoiceTokens.Motion.spring, value: granted)
        .onAppear { if granted { monitor.start() } }
        .onDisappear { monitor.stop() }
        // If the user grants mic access while standing on this step, spin the engine up live.
        .onChange(of: granted) { _, isGranted in
            if isGranted { monitor.start() } else { monitor.stop() }
        }
    }

    private var micPrompt: some View {
        VStack(spacing: KeyVoiceTokens.Spacing.m) {
            Image(systemName: "mic.slash.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(KeyVoiceTokens.Colors.amber)
                .frame(width: 96, height: 96)
                .glassSurface(shape: Circle())

            Text("Microphone access is off. Turn it on and KeyVoice will start listening.")
                .font(KeyVoiceTokens.Typography.body)
                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button("Enable microphone", action: requestAccess)
                .buttonStyle(.borderedProminent)
                .tint(KeyVoiceTokens.Colors.ice)
                .controlSize(.regular)
        }
    }
}

/// A glowing ice orb that grows and brightens with the live mic level. Pure SwiftUI so it stays
/// cheap: the whole thing is a couple of circles whose scale/opacity read off `level` (0...1).
private struct MicOrb: View {
    /// Smoothed input level, 0...1.
    let level: Double

    var body: some View {
        let clamped = max(0, min(1, level))
        ZStack {
            // Outer breath: a soft blurred halo that swells with loudness.
            Circle()
                .fill(KeyVoiceTokens.Colors.ice.opacity(0.18 + 0.4 * clamped))
                .blur(radius: 24)
                .scaleEffect(0.75 + 0.7 * clamped)

            // Reacting ring that traces the current level.
            Circle()
                .strokeBorder(KeyVoiceTokens.Colors.ice.opacity(0.35 + 0.5 * clamped), lineWidth: 2)
                .scaleEffect(0.62 + 0.5 * clamped)

            // The core orb: an ice-gradient glass disc that pulses with the voice.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            KeyVoiceTokens.Colors.ice
                        ],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: 60
                    )
                )
                .overlay(
                    Circle().strokeBorder(KeyVoiceTokens.Colors.glassStroke, lineWidth: 0.75)
                )
                .frame(width: 84, height: 84)
                .scaleEffect(0.9 + 0.35 * clamped)
                .shadow(color: KeyVoiceTokens.Colors.ice.opacity(0.5 * clamped), radius: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(KeyVoiceTokens.Motion.quick, value: clamped)
        .accessibilityLabel("Microphone level")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

// MARK: - Permission card

/// One row of the permissions step: icon, title + why, a live status dot, and an action button —
/// now seated on a glass card with an ice edge once granted.
private struct PermissionCard: View {
    let permission: Permission
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: KeyVoiceTokens.Spacing.m) {
            Image(systemName: permission.symbol)
                .font(.system(size: 20, weight: .regular))
                .frame(width: 28)
                .foregroundStyle(granted ? KeyVoiceTokens.Colors.ice : KeyVoiceTokens.Colors.ink.opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: KeyVoiceTokens.Spacing.xs) {
                    Text(permission.title)
                        .font(KeyVoiceTokens.Typography.headline)
                        .foregroundStyle(KeyVoiceTokens.Colors.ink)
                    StatusDot(granted: granted)
                }
                Text(permission.reason)
                    .font(KeyVoiceTokens.Typography.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: KeyVoiceTokens.Spacing.s)

            if granted {
                Text("Granted")
                    .font(KeyVoiceTokens.Typography.body.weight(.medium))
                    .foregroundStyle(KeyVoiceTokens.Colors.ice)
            } else {
                Button("Enable", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(KeyVoiceTokens.Colors.ice)
                    .controlSize(.small)
            }
        }
        .padding(KeyVoiceTokens.Spacing.m)
        .glassSurface(shape: RoundedRectangle(cornerRadius: KeyVoiceTokens.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KeyVoiceTokens.Radius.medium, style: .continuous)
                .strokeBorder(granted ? KeyVoiceTokens.Colors.ice.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .animation(KeyVoiceTokens.Motion.spring, value: granted)
    }
}

/// Ice when granted, muted ink otherwise. The one thing the eye tracks while granting.
private struct StatusDot: View {
    let granted: Bool

    var body: some View {
        Circle()
            .fill(granted ? KeyVoiceTokens.Colors.ice : KeyVoiceTokens.Colors.ink.opacity(0.3))
            .frame(width: 8, height: 8)
            .accessibilityLabel(granted ? "Granted" : "Not granted")
    }
}

/// Little progress pips in the bottom bar so the user knows how far along they are.
private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: KeyVoiceTokens.Spacing.s) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? KeyVoiceTokens.Colors.ice : KeyVoiceTokens.Colors.ink.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .animation(KeyVoiceTokens.Motion.quick, value: current)
            }
        }
    }
}
