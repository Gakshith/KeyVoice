import SwiftUI

/// Shared visual constants for KeyVoice's frozen-glass interface.
public enum KeyVoiceTokens {
    public enum Colors {
        /// Adaptive primary ink: near-black in light mode and near-white in dark mode.
        public static let ink = Color.primary
        public static let ice = Color(red: 0.66, green: 0.85, blue: 1.0)
        public static let amber = Color(red: 0.90, green: 0.69, blue: 0.44)

        /// Subtle fills and edges for composing custom glass treatments.
        public static let glassGround = Color.primary.opacity(0.06)
        public static let glassHighlight = Color.white.opacity(0.16)
        public static let glassStroke = Color.white.opacity(0.28)
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 20
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 14
        public static let pill: CGFloat = 999
    }

    /// SF Pro type styles. `Font.system` uses the platform system face on macOS.
    public enum Typography {
        public static let title = Font.system(size: 28, weight: .semibold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 14, weight: .regular)
        public static let caption = Font.system(size: 11, weight: .semibold)
    }

    public enum Motion {
        public static let spring = Animation.spring(response: 0.34, dampingFraction: 0.7)
        public static let quick = Animation.spring(response: 0.2, dampingFraction: 0.82)
    }
}
