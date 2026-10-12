import SwiftUI
import HeroDomain
import HeroContent

/// Doc 33: today's challenge offer, a glass card at the top of Home over the scene. The name, the attribute
/// tested in its colour, the odds as one word, a hint naming what moves them, the challenger's card portrait,
/// and the record on a repeat. Accept is the filled control; "Not today" is smaller and quiet. The band
/// recomputes whenever the ledger changes, so training today shows up here before the clash.
struct ChallengeCard: View {
    @Environment(AppState.self) private var state
    let onAccept: () -> Void

    var body: some View {
        if let offer = state.todayOffer, let challenge = state.bundle.challenge(offer.challengeID), let who = state.bundle.character(challenge.characterID) {
            let odds = state.odds(for: challenge)
            let record = state.challengeRecord(challenge.id)
            let attribute = state.bundle.attributes.first { $0.id == challenge.attributeID }
            let attributeColor = NeoTokyo.Attribute.color(for: challenge.attributeID.rawValue)
            HStack(alignment: .top, spacing: NeoTokyo.Spacing.md) {
                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
                    Eyebrow(text: "\(who.displayName) · \(challenge.difficulty)")
                    Text(challenge.name).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                    HStack(spacing: 6) {
                        Text(attribute?.displayName ?? challenge.attributeID.rawValue).font(HeroFont.captionMedium).foregroundStyle(attributeColor)
                        Text("·").foregroundStyle(NeoTokyo.Text.muted)
                        Text(odds.band.rawValue).font(HeroFont.captionMedium).foregroundStyle(bandColor(odds.band, attributeColor))
                            .contentTransition(.opacity)
                    }
                    Text(hint(odds: odds, record: record)).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: NeoTokyo.Spacing.sm) {
                        Button("Accept") { onAccept() }.buttonStyle(PrimaryButtonStyle())
                        Button("Not today") { state.declineChallenge() }
                            .buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Text.secondary))
                            .frame(maxWidth: 110)
                    }
                    .padding(.top, NeoTokyo.Spacing.xs)
                }
                if let portrait = who.cardPortrait {
                    PortraitView(assetSetID: portrait, size: 84)
                        .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                        .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay)
                }
            }
            .padding(NeoTokyo.Spacing.md)
            .glass(tint: NeoTokyo.Surface.raised)
            .animation(.easeOut(duration: 0.3), value: odds.band)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func bandColor(_ band: ChallengeBand, _ attribute: Color) -> Color {
        switch band {
        case .likely: return NeoTokyo.Hierarchy.primary
        case .even: return NeoTokyo.Text.primary
        case .longShot: return NeoTokyo.Text.secondary
        }
    }

    /// Under the band: how to move it today, or, when it already moved, that it did; the record on a repeat.
    private func hint(odds: AppState.ChallengeOdds, record: (won: Int, lost: Int)) -> String {
        var parts: [String] = []
        let families = odds.helpingFamilies.compactMap { state.bundle.family($0)?.displayName }
        if odds.bonus > 0 { parts.append("Today's training is counting.") }
        else if odds.band != .likely, let first = families.first { parts.append("\(first) today moves the odds.") }
        if record.won + record.lost > 0 { parts.append("Won \(record.won) · Lost \(record.lost)") }
        return parts.joined(separator: " ")
    }
}
