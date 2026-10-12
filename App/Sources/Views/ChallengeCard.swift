import SwiftUI
import HeroDomain
import HeroContent

/// Doc 33: today's challenge offer, a glass card that overlaps the foot of the scene (owner build notes 2026-10-12).
/// "Challenge · Cairon", the name, the attribute with its glyph, "Outcome: Likely". The difficulty is never shown;
/// the outcome word carries it. One line says whether today's workout moved the odds. "Not today" left and quiet,
/// Accept right and filled. The band recomputes whenever the ledger changes.
struct ChallengeCard: View {
    @Environment(AppState.self) private var state
    let onAccept: () -> Void

    var body: some View {
        if let offer = state.todayOffer, let challenge = state.bundle.challenge(offer.challengeID), let who = state.bundle.character(challenge.characterID) {
            let odds = state.odds(for: challenge)
            let record = state.challengeRecord(challenge.id)
            let attribute = state.bundle.attributes.first { $0.id == challenge.attributeID }
            let attributeColor = NeoTokyo.Attribute.color(for: challenge.attributeID.rawValue)
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                HStack(alignment: .top, spacing: NeoTokyo.Spacing.md) {
                    VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
                        Eyebrow(text: "Challenge · \(who.displayName)")
                        Text(challenge.name).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                        HStack(spacing: 6) {
                            Image(systemName: AttributeGlyph.symbol(for: challenge.attributeID)).font(HeroFont.captionMedium)
                            Text(attribute?.displayName ?? challenge.attributeID.rawValue).font(HeroFont.captionMedium)
                        }
                        .foregroundStyle(attributeColor)
                        HStack(spacing: 6) {
                            Text("Outcome:").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                            Text(odds.band.rawValue).font(HeroFont.captionMedium).foregroundStyle(bandColor(odds.band))
                                .contentTransition(.opacity)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: odds.bonus > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(HeroFont.label)
                                .foregroundStyle(odds.bonus > 0 ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                            Text(odds.bonus > 0 ? "Today's workout boosted your odds" : "Logging a workout increases odds")
                                .font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                        }
                        if record.won + record.lost > 0 {
                            Text("Won \(record.won) · Lost \(record.lost)").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.muted)
                        }
                    }
                    Spacer(minLength: 0)
                    if let portrait = who.cardPortrait {
                        PortraitView(assetSetID: portrait, size: 84)
                            .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay)
                    }
                }
                HStack(spacing: NeoTokyo.Spacing.sm) {
                    Button("Not today") { state.declineChallenge() }
                        .buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Text.secondary))
                        .frame(maxWidth: 120)
                    Button("Accept") { onAccept() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(NeoTokyo.Spacing.md)
            .glass(tint: NeoTokyo.Surface.raised)
            .animation(.easeOut(duration: 0.3), value: odds.band)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func bandColor(_ band: ChallengeBand) -> Color {
        switch band {
        case .likely: return NeoTokyo.Hierarchy.primary
        case .even: return NeoTokyo.Text.primary
        case .longShot: return NeoTokyo.Text.secondary
        }
    }
}
