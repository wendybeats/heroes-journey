import SwiftUI

/// Shared view styles. Doc 19 rules: one accent per region, accents as light not fill,
/// navy surfaces, no gradients on chrome.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(NeoTokyo.Spacing.lg)
            .background(NeoTokyo.Surface.raised, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous).strokeBorder(NeoTokyo.Surface.line, lineWidth: 1))
    }
}

/// The single filled button on a screen (doc 19 rule 3).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(NeoTokyo.Text.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.md)
            .background(NeoTokyo.Accent.pink.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
    }
}

/// Outlined secondary action: accent as a hairline, not a fill.
struct SecondaryButtonStyle: ButtonStyle {
    var accent: Color = NeoTokyo.Accent.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
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

/// Monospaced digits so XP counters do not jitter.
struct StatNumber: View {
    let value: Int
    let accent: Color
    var body: some View {
        Text(value, format: .number)
            .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
            .foregroundStyle(accent)
    }
}
