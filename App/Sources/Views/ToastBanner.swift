import SwiftUI

/// Owner 2026-10-12: a small, quick toast that slides up into the page above the stats, holds a moment, and slides
/// out. One pattern for "New quest area unlocked", "Level up" and "Ascension"; the gold style is for the ascension,
/// with a light-gold face and sparkles. Presented by Home; see `HomeView.showToast`.
struct ToastItem: Identifiable, Equatable {
    enum Style: Equatable { case standard, gold }
    let id = UUID()
    let text: String
    let symbol: String
    var style: Style = .standard
    var holdSeconds: Double = 1.6
}

struct ToastBanner: View {
    let item: ToastItem
    @State private var sparkle = false

    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            Image(systemName: item.symbol).font(HeroFont.headline).foregroundStyle(iconColor)
            Text(item.text).font(HeroFont.bodyMedium).foregroundStyle(textColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NeoTokyo.Spacing.md)
        .padding(.vertical, NeoTokyo.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(background, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
        .overlay {
            if item.style == .gold {
                // Sparkles on the gold card: four small marks that breathe once while the toast holds.
                GeometryReader { geo in
                    ForEach(0..<4, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: i % 2 == 0 ? 10 : 7))
                            .foregroundStyle(i % 2 == 0 ? NeoTokyo.Text.primary : NeoTokyo.Hierarchy.primary)
                            .opacity(sparkle ? 1 : 0.25)
                            .position(x: geo.size.width * [0.62, 0.74, 0.88, 0.95][i], y: geo.size.height * [0.25, 0.7, 0.35, 0.78][i])
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .shadow(color: NeoTokyo.Surface.scrim.opacity(0.5), radius: 10, y: 4)
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { sparkle = true } }
    }

    private var background: some ShapeStyle {
        item.style == .gold ? AnyShapeStyle(NeoTokyo.Hierarchy.primary) : AnyShapeStyle(NeoTokyo.Surface.overlay)
    }
    private var textColor: Color { item.style == .gold ? NeoTokyo.Text.onAccent : NeoTokyo.Text.primary }
    private var iconColor: Color { item.style == .gold ? NeoTokyo.Text.onAccent : NeoTokyo.Hierarchy.primary }
}
