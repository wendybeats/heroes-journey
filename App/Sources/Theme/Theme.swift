import SwiftUI

/// Shared view styles. Doc 19 rules plus the 2026-09-29 pass: surfaces are glass, cards sit
/// close to the background with no colored border, elevation comes from material not color.
///
/// Liquid Glass (`glassEffect`) exists from the iOS 26 SDK. The app's deployment target is iOS 17
/// and CI compiles with Xcode 16, so the glass call is guarded twice: at compile time on the
/// compiler version, and at runtime on availability. Older SDKs and OS versions get a thin
/// material tinted with the surface color.
struct GlassSurface: ViewModifier {
    var shape: RoundedRectangle
    var tint: Color = NeoTokyo.Surface.raised

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background(tint.opacity(0.55), in: shape)
                .glassEffect(.regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .background(tint.opacity(0.7), in: shape)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(NeoTokyo.Spacing.lg)
            .modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous)))
    }
}

/// The single filled button on a screen: off-white with a hint of blue, navy text.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeroFont.headline)
            .foregroundStyle(NeoTokyo.Text.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.md)
            .background(configuration.isPressed ? NeoTokyo.Accent.buttonDim : NeoTokyo.Accent.button, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
    }
}

/// Glass secondary action: accent text on glass, no border.
struct SecondaryButtonStyle: ButtonStyle {
    var accent: Color = NeoTokyo.Text.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeroFont.bodyMedium)
            .foregroundStyle(accent.opacity(configuration.isPressed ? 0.7 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.md)
            .modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous), tint: NeoTokyo.Surface.overlay))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
    func glass(cornerRadius: CGFloat = NeoTokyo.Radius.lg, tint: Color = NeoTokyo.Surface.raised) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint))
    }
}

/// A large tabular number with an optional unit, e.g. "184" / "xp" or "142" / "min".
/// `value` animates: change it inside `withAnimation` and the digits count up.
struct StatNumber: View {
    let value: Int
    var unit: String? = nil
    var accent: Color = NeoTokyo.Text.primary
    var font: Font = HeroFont.statMD
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            CountingText(value: Double(value), font: font, color: accent)
            if let unit { Text(unit).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary) }
        }
    }
}

/// Text whose integer value interpolates under animation (a count-up, not a digit flip).
struct CountingText: View, @preconcurrency Animatable {
    var value: Double
    var font: Font
    var color: Color
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text(Int(value.rounded()), format: .number).font(font).foregroundStyle(color)
    }
}

/// "+n" that fades in, holds, and fades out. Re-triggers whenever `token` changes.
struct DeltaBadge: View {
    let delta: Int
    let token: Int
    var color: Color = NeoTokyo.Hierarchy.primary
    @State private var visible = false
    var body: some View {
        Text("+\(delta)")
            .font(HeroFont.captionNumber)
            .foregroundStyle(color)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 6)
            .task(id: token) {
                guard delta > 0 else { visible = false; return }
                withAnimation(.easeOut(duration: 0.3)) { visible = true }
                try? await Task.sleep(for: .milliseconds(2000))
                withAnimation(.easeIn(duration: 0.4)) { visible = false }
            }
    }
}
