import SwiftUI

/// Shared view styles. Doc 19 rules: one accent per region, gold is primary, accents as light
/// not fill, navy surfaces, no gradients on chrome.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(NeoTokyo.Spacing.lg)
            .background(NeoTokyo.Surface.raised, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous).strokeBorder(NeoTokyo.Surface.line, lineWidth: 1))
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

/// Outlined secondary action: accent as a hairline, not a fill. Defaults to the first fallback accent.
struct SecondaryButtonStyle: ButtonStyle {
    var accent: Color = NeoTokyo.Hierarchy.fallback
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HeroFont.bodyMedium)
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.md)
            .background(NeoTokyo.Surface.raised, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous).strokeBorder(accent.opacity(configuration.isPressed ? 1 : 0.6), lineWidth: 1))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// A large tabular number with an optional unit, e.g. "184" / "xp" or "142" / "min".
struct StatNumber: View {
    let value: Int
    var unit: String? = nil
    var accent: Color = NeoTokyo.Text.primary
    var font: Font = HeroFont.statMD
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value, format: .number).font(font).foregroundStyle(accent)
            if let unit { Text(unit).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary) }
        }
    }
}
