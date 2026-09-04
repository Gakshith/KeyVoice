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

        // MARK: - Studio (warm paper) — the primary app surface. Fixed light world.
        public static let paper   = Color(red: 0.965, green: 0.957, blue: 0.937) // #f6f4ef
        public static let paper2  = Color(red: 0.937, green: 0.925, blue: 0.890) // #efece3
        public static let card    = Color.white
        public static let card2   = Color(red: 0.980, green: 0.973, blue: 0.953) // #faf8f3
        public static let line    = Color(red: 0.910, green: 0.890, blue: 0.847) // #e8e3d8
        public static let velvet  = Color(red: 0.082, green: 0.075, blue: 0.063) // #151310

        public static let text    = Color(red: 0.106, green: 0.102, blue: 0.090) // #1b1a17
        public static let text2   = Color(red: 0.341, green: 0.322, blue: 0.286) // #575249
        public static let fog     = Color(red: 0.561, green: 0.541, blue: 0.494) // #8f8a7e

        public static let accent     = Color(red: 0.357, green: 0.294, blue: 1.0) // #5b4bff
        public static let accentSoft = Color(red: 0.925, green: 0.914, blue: 1.0) // #ece9ff
        public static let good       = Color(red: 0.184, green: 0.749, blue: 0.431) // #2fbf6e (live/privacy)

        /// The voice spectrum — used ONLY on sound moments (hero, pill, sparkline, listening).
        public static let s1 = Color(red: 0.416, green: 0.298, blue: 1.0)   // #6a4cff
        public static let s2 = Color(red: 0.298, green: 0.482, blue: 1.0)   // #4c7bff
        public static let s3 = Color(red: 0.184, green: 0.816, blue: 0.812) // #2fd0cf
        public static let s4 = Color(red: 1.0,   green: 0.694, blue: 0.306) // #ffb14e
        public static let s5 = Color(red: 1.0,   green: 0.361, blue: 0.541) // #ff5c8a
        public static let spectrum: [Color] = [s1, s2, s3, s4, s5]

        /// Left→right spectrum gradient for waveforms and sparklines.
        public static let spectrumGradient = LinearGradient(
            colors: spectrum, startPoint: .leading, endPoint: .trailing
        )
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
