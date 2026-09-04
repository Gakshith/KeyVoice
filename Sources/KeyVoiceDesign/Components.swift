import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(KeyVoiceTokens.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
    }
}

public struct GlassPanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(KeyVoiceTokens.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassSurface(
                shape: RoundedRectangle(
                    cornerRadius: KeyVoiceTokens.Radius.medium,
                    style: .continuous
                )
            )
    }
}

public struct StatTile: View {
    private let title: String
    private let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.s) {
            Text(value)
                .font(KeyVoiceTokens.Typography.title)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(KeyVoiceTokens.Colors.ink)

            Text(title.uppercased())
                .font(KeyVoiceTokens.Typography.caption)
                .tracking(1.1)
                .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.62))
        }
        .padding(KeyVoiceTokens.Spacing.l)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .glassSurface()
    }
}

public struct SectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(KeyVoiceTokens.Typography.caption)
            .tracking(1.6)
            .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.62))
    }
}

public struct GlassRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: KeyVoiceTokens.Spacing.m) {
            leading
            Spacer(minLength: KeyVoiceTokens.Spacing.m)
            trailing
        }
        .font(KeyVoiceTokens.Typography.body)
        .foregroundStyle(KeyVoiceTokens.Colors.ink)
        .padding(.horizontal, KeyVoiceTokens.Spacing.l)
        .padding(.vertical, KeyVoiceTokens.Spacing.m)
        .glassSurface()
    }
}
