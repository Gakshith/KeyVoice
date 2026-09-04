import SwiftUI

/// Applies native Liquid Glass on macOS 26 and a material-based fallback on older macOS releases.
public struct GlassSurfaceModifier<SurfaceShape: InsettableShape>: ViewModifier {
    private let shape: SurfaceShape

    public init(shape: SurfaceShape) {
        self.shape = shape
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(KeyVoiceTokens.Colors.glassStroke, lineWidth: 0.75)
                }
        }
    }
}

public extension View {
    /// Presents this view on a glass surface using the supplied insettable shape.
    func glassSurface<SurfaceShape: InsettableShape>(shape: SurfaceShape) -> some View {
        modifier(GlassSurfaceModifier(shape: shape))
    }

    /// Presents this view on the standard KeyVoice rounded-rectangle glass surface.
    func glassSurface() -> some View {
        glassSurface(
            shape: RoundedRectangle(
                cornerRadius: KeyVoiceTokens.Radius.medium,
                style: .continuous
            )
        )
    }
}
