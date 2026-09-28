import SwiftUI

/// Fitness-app typography (doc 19). Barlow for UI, Barlow Semi Condensed for stats.
/// Every numeric style enables tabular figures so counters and columns never jitter.
/// Sizes come from the generated `NeoTokyo.Type` scale; text still scales with Dynamic Type
/// because `Font.custom(_:size:)` is relative to the body text style.
enum HeroFont {
    // Stats: condensed, athletic, always tabular.
    static var statXL: Font { .custom(NeoTokyo.Type.statBold, size: NeoTokyo.Type.statXl).monospacedDigit() }
    static var statLG: Font { .custom(NeoTokyo.Type.statBold, size: NeoTokyo.Type.statLg).monospacedDigit() }
    static var statMD: Font { .custom(NeoTokyo.Type.statSemibold, size: NeoTokyo.Type.statMd).monospacedDigit() }
    static var statSM: Font { .custom(NeoTokyo.Type.statSemibold, size: NeoTokyo.Type.statSm).monospacedDigit() }

    // UI text.
    static var title: Font { .custom(NeoTokyo.Type.uiSemibold, size: NeoTokyo.Type.title) }
    static var headline: Font { .custom(NeoTokyo.Type.uiSemibold, size: NeoTokyo.Type.headline) }
    static var body: Font { .custom(NeoTokyo.Type.uiRegular, size: NeoTokyo.Type.body) }
    static var bodyMedium: Font { .custom(NeoTokyo.Type.uiMedium, size: NeoTokyo.Type.body) }
    static var callout: Font { .custom(NeoTokyo.Type.uiRegular, size: NeoTokyo.Type.callout) }
    static var caption: Font { .custom(NeoTokyo.Type.uiRegular, size: NeoTokyo.Type.caption) }
    static var captionMedium: Font { .custom(NeoTokyo.Type.uiMedium, size: NeoTokyo.Type.caption) }
    /// Uppercase eyebrow labels; pair with `.tracking(0.8)` and `.textCase(.uppercase)`.
    static var label: Font { .custom(NeoTokyo.Type.uiMedium, size: NeoTokyo.Type.label) }
    /// Inline numbers inside body-sized text (durations in a row, "+18 Strength").
    static var bodyNumber: Font { .custom(NeoTokyo.Type.uiMedium, size: NeoTokyo.Type.body).monospacedDigit() }
    static var captionNumber: Font { .custom(NeoTokyo.Type.uiMedium, size: NeoTokyo.Type.caption).monospacedDigit() }
}

/// Small uppercase section label.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HeroFont.label)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(NeoTokyo.Text.secondary)
    }
}
