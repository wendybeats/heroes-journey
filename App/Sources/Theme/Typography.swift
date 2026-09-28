import SwiftUI

/// Fitness-app typography (doc 19). Barlow for UI, Barlow Semi Condensed for stats.
/// Every numeric style enables tabular figures so counters and columns never jitter.
/// Sizes come from the generated `NeoTokyo.Typeface` scale; text still scales with Dynamic Type
/// because `Font.custom(_:size:)` is relative to the body text style.
enum HeroFont {
    // Stats: condensed, athletic, always tabular.
    static var statXL: Font { .custom(NeoTokyo.Typeface.statBold, size: NeoTokyo.Typeface.statXl).monospacedDigit() }
    static var statLG: Font { .custom(NeoTokyo.Typeface.statBold, size: NeoTokyo.Typeface.statLg).monospacedDigit() }
    static var statMD: Font { .custom(NeoTokyo.Typeface.statSemibold, size: NeoTokyo.Typeface.statMd).monospacedDigit() }
    static var statSM: Font { .custom(NeoTokyo.Typeface.statSemibold, size: NeoTokyo.Typeface.statSm).monospacedDigit() }

    // UI text.
    static var title: Font { .custom(NeoTokyo.Typeface.uiSemibold, size: NeoTokyo.Typeface.title) }
    static var headline: Font { .custom(NeoTokyo.Typeface.uiSemibold, size: NeoTokyo.Typeface.headline) }
    static var body: Font { .custom(NeoTokyo.Typeface.uiRegular, size: NeoTokyo.Typeface.body) }
    static var bodyMedium: Font { .custom(NeoTokyo.Typeface.uiMedium, size: NeoTokyo.Typeface.body) }
    static var callout: Font { .custom(NeoTokyo.Typeface.uiRegular, size: NeoTokyo.Typeface.callout) }
    static var caption: Font { .custom(NeoTokyo.Typeface.uiRegular, size: NeoTokyo.Typeface.caption) }
    static var captionMedium: Font { .custom(NeoTokyo.Typeface.uiMedium, size: NeoTokyo.Typeface.caption) }
    /// Uppercase eyebrow labels; pair with `.tracking(0.8)` and `.textCase(.uppercase)`.
    static var label: Font { .custom(NeoTokyo.Typeface.uiMedium, size: NeoTokyo.Typeface.label) }
    /// Inline numbers inside body-sized text (durations in a row, "+18 Strength").
    static var bodyNumber: Font { .custom(NeoTokyo.Typeface.uiMedium, size: NeoTokyo.Typeface.body).monospacedDigit() }
    static var captionNumber: Font { .custom(NeoTokyo.Typeface.uiMedium, size: NeoTokyo.Typeface.caption).monospacedDigit() }
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
