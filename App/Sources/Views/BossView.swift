import SwiftUI
import HeroDomain
import HeroContent

/// Doc 36 §33 combat screen, owner handoff 2026-10-16 (colossus-proof-v1). The engine decides; this plays its
/// events. Both actors stand on one floor line, positioned by their pivots at one shared integer scale (the
/// registration rule: never fit a pose to a box). A player action is the §18 sequence: the real customised idle
/// → eyes ignite → the real sprite whites out → the white shape becomes the action master → the master shows in its
/// attribute glow and moves → impact → returns → whites out → the real sprite comes back. Colossus swaps between
/// his four states on his events. Every effect here is procedural (Tier 1 of §32); nothing is baked into the art.
struct BossFight: Identifiable {
    let encounter: BossEncounter
    let milestone: Milestone?
    /// Dev: a row of boss-state buttons to review transitions without the engine.
    var rehearsal = false
    var id: String { encounter.boss.id.rawValue }
}

struct BossView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fight: BossFight
    let onFinish: (CombatResult) -> Void

    @State private var encounter: BossEncounter
    @State private var busy = false
    // Shown numbers move at the moment the event plays, not when the engine resolves.
    @State private var shownPlayer: Double
    @State private var shownBoss: Double
    @State private var shownBreak: Double
    @State private var shownBroken = false
    @State private var shownPressure = 0
    // Hero sequence
    enum HeroPhase { case idle, eyes, whiteReal, whiteAction, action }
    @State private var heroPhase: HeroPhase = .idle
    @State private var heroAction: CombatAction = .attack
    @State private var heroLunge: CGFloat = 0
    @State private var heroHit = 0.0
    // Colossus
    @State private var bossAnim = "idle"
    @State private var bossLunge: CGFloat = 0
    @State private var bossHit = 0.0
    @State private var outline = 0.0
    @State private var scan: CGFloat? = nil
    // Shared effects
    @State private var flash = 0.0
    @State private var shake: CGFloat = 0
    @State private var stageShake = CGSize.zero
    @State private var afterAlpha = 0.0
    @State private var afterX: CGFloat = 0
    @State private var bossAura = 0.0
    @State private var bossAuraColor: Color = NeoTokyo.Attribute.color(for: "strength")
    @State private var shatter = false
    @State private var ring: Ring? = nil
    @State private var pop: Pop? = nil
    @State private var line: String? = nil
    /// What Colossus just did, shown while he does it (owner QA 2026-10-16: no advance telegraph).
    @State private var narration: String? = nil
    /// Analyze read him: his next move shows until the player's next action. Otherwise the tell is the pattern.
    @State private var readNext = false
    @State private var hint: String? = nil
    @State private var shownHints: Set<String> = []

    /// Where a piece of feedback lands (owner brief 2026-10-16, P0-4): fixed anchors, clamped inside the stage.
    enum PopAnchor { case bossTorso, heroTorso, playerStatus, bossCenter }
    struct Pop: Identifiable {
        let id = UUID(); let text: String; let anchor: PopAnchor; let color: Color; let big: Bool
        var sub: String? = nil
        init(text: String, onBoss: Bool, color: Color, big: Bool, sub: String? = nil) {
            self.text = text; self.anchor = onBoss ? .bossTorso : .heroTorso; self.color = color; self.big = big; self.sub = sub
        }
        init(text: String, at anchor: PopAnchor, color: Color, big: Bool, sub: String? = nil) {
            self.text = text; self.anchor = anchor; self.color = color; self.big = big; self.sub = sub
        }
    }
    /// Break damage shows beside the Break meter, not on the stage (P0-4).
    @State private var breakPop: String? = nil
    /// P1-6: the room darkens for a moment on MORE; `moreCount` keeps a faint strength aura on him that grows with each one.
    @State private var dim = 0.0
    @State private var moreCount = 0
    /// P1-7: the one escalation beat, at `boss.phaseAt` of his Stamina; `phaseBanner` is its title while it plays.
    @State private var phaseShown = false
    @State private var phaseBanner: String? = nil
    /// P1-5: Pressure is explained in full the first time it lands and the first time it clears, compact after.
    @State private var pressureExplained = false
    @State private var clearExplained = false
    /// P1-8: after the last hit he stays down and the room goes quiet before the card.
    @State private var defeated = false
    /// A Guard waits for his hit: the brace is shown, the ripple plays on impact (P0-1, P0-2).
    @State private var guardPending: Double? = nil
    struct Ring: Identifiable, Equatable { let id = UUID(); let color: Color; let inward: Bool }

    init(fight: BossFight, onFinish: @escaping (CombatResult) -> Void) {
        self.fight = fight; self.onFinish = onFinish
        _encounter = State(initialValue: fight.encounter)
        _shownPlayer = State(initialValue: fight.encounter.playerStamina); _shownBoss = State(initialValue: fight.encounter.bossStamina)
        _shownBreak = State(initialValue: fight.encounter.breakNow)
    }

    private var boss: BossDefinition { encounter.boss }
    private var backdrop: BackdropID {
        let id: BackdropID = "backdrop.colossus_gym.interior_01"
        return BackdropID(state.bundle.backdrop(id)?.assetSetID.rawValue ?? id.rawValue)
    }
    private var bossSet: AssetSetID { AssetSetID(boss.assets["idle"] ?? "npc.colossus.combat") }
    private var heroMasters: AssetSetID { AssetSetID(boss.assets["player.\(state.recipe?.baseBody.rawValue ?? "male")"] ?? boss.assets["player.male"] ?? "hero.combat.male") }
    private static let scale: CGFloat = HomeView.characterScale
    private static let heroCanvas = CGSize(width: 64, height: 128), heroPivot = CGPoint(x: 32, y: 122)
    private static let combatCanvas = CGSize(width: 160, height: 192), combatPivot = CGPoint(x: 80, y: 184)
    private static let heroX: CGFloat = 0.22, bossX: CGFloat = 0.77
    private var actionColor: Color { NeoTokyo.Attribute.color(for: heroAction.attributeID.rawValue) }

    var body: some View {
        VStack(spacing: 0) {
            bossPanel
            stage
            playerPanel
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .overlay { Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false) }
        .overlay { pressureVignette }
        .overlay { if let result = encounter.result, !busy { resultCard(result).transition(.scale(scale: 0.92).combined(with: .opacity)) } }
        .animation(.easeOut(duration: 0.25), value: busy)
        .onAppear { showHint("attack") }
    }

    // MARK: boss panel

    /// Owner QA 2026-10-16: his bar sits left at 70 % width, yours right under your name; neither runs edge to edge.
    private var bossPanel: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(boss.displayName).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                Text("\(max(0, Int(shownBoss.rounded())))").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.primary)
                    .contentTransition(.numericText(value: shownBoss))
            }
            bar(value: shownBoss / encounter.bossStaminaMax, tint: NeoTokyo.Text.primary)
                .containerRelativeFrame(.horizontal, count: 10, span: 7, spacing: 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Text("BREAK").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                ForEach(0..<Int(encounter.breakMax.rounded()), id: \.self) { i in
                    let lit = Double(i) < shownBreak.rounded(.up) && !shownBroken
                    Image(systemName: lit ? "diamond.fill" : "diamond")
                        .font(HeroFont.label)
                        .foregroundStyle(shownBroken ? NeoTokyo.Hierarchy.primary : NeoTokyo.Attribute.color(for: "knowledge"))
                        .scaleEffect(shatter && lit ? 1.9 : 1).opacity(shatter && lit ? 0 : 1)
                }
                if shownBroken { Text("BROKEN").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.primary).transition(.opacity) }
                if let breakPop {
                    Text(breakPop).font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Attribute.color(for: "knowledge"))
                        .id(breakPop).transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.easeOut(duration: 0.2), value: breakPop)
            .animation(.easeOut(duration: 0.35), value: shatter)
            .animation(.easeOut(duration: 0.2), value: shownBroken)
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.top, DeviceInsets.top + NeoTokyo.Spacing.sm)
        .padding(.bottom, NeoTokyo.Spacing.sm)
    }

    // MARK: stage

    /// Frame a canvas at the shared scale and put its pivot on `anchor`.
    private func placed<V: View>(_ view: V, canvas: CGSize, pivot: CGPoint, at anchor: CGPoint) -> some View {
        let s = Self.scale
        return view
            .frame(width: canvas.width * s, height: canvas.height * s)
            .position(x: anchor.x - pivot.x * s + canvas.width * s / 2, y: anchor.y - pivot.y * s + canvas.height * s / 2)
    }

    private var stage: some View {
        GeometryReader { geo in
            let floorY = geo.size.height * 0.86
            // Owner QA 2026-10-16: the two stand near the edges, not the middle.
            let heroAnchor = CGPoint(x: geo.size.width * Self.heroX + heroLunge, y: floorY)
            let bossAnchor = CGPoint(x: geo.size.width * Self.bossX + bossLunge + shake, y: floorY)
            ZStack {
                BackdropImage(assetSetID: backdrop)
                // P2-10: the environment keeps its identity but sits a shade under the characters and the feedback;
                // P1-6: MORE and the phase beat darken it further for a moment; P1-8: the room goes quiet when he is down.
                NeoTokyo.Surface.scrim.opacity(0.22 + dim).allowsHitTesting(false)
                // Ascension field under the hero's feet (doc 36 §20: the tier modifies the presentation, not the animation).
                if state.ascensionTier >= 1 {
                    Ellipse().fill(NeoTokyo.Hierarchy.primary.opacity(state.ascensionTier >= 2 ? 0.22 : 0.12))
                        .frame(width: 120, height: 18).blur(radius: 10)
                        .position(x: heroAnchor.x, y: floorY - 2)
                    if state.ascensionTier >= 2 { AscensionParticles(color: NeoTokyo.Hierarchy.primary).frame(width: 90, height: 160).position(x: heroAnchor.x, y: floorY - 90) }
                }
                // Colossus: his aura while he moves (owner 2026-10-16: an iron-and-pressure bloom on Crush, LOAD and MORE,
                // gold on the Break), the Analyze outline, the state sprite, a white hit flash over it.
                bossLayers(bossAnchor: bossAnchor, floorY: floorY, size: geo.size)
                heroLayers(heroAnchor: heroAnchor, floorY: floorY, size: geo.size)
                if let ring {
                    RingView(color: ring.color, inward: ring.inward).frame(width: 150, height: 150).position(x: heroAnchor.x, y: floorY - 70).id(ring.id)
                }
                if let pop { popView(pop, size: geo.size, heroAnchor: heroAnchor, bossAnchor: bossAnchor, floorY: floorY) }
                // Telegraph and the dialogue banner, between the two.
                VStack(spacing: 6) {
                    if let line {
                        Text("“\(line)”").font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay).transition(.opacity)
                    }
                    if let phaseBanner {
                        Text(phaseBanner).font(HeroFont.title).foregroundStyle(NeoTokyo.Hierarchy.primary)
                            .padding(.horizontal, NeoTokyo.Spacing.lg).padding(.vertical, NeoTokyo.Spacing.sm)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                            .transition(.scale(scale: 1.2).combined(with: .opacity))
                    } else if shownBroken, !busy, encounter.result == nil {
                        Text("BROKEN · one free action").font(HeroFont.headline).foregroundStyle(NeoTokyo.Hierarchy.primary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                            .transition(.scale(scale: 1.15).combined(with: .opacity))
                    } else if let narration {
                        Text(narration).font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                            .id(narration).transition(.opacity)
                    } else if readNext, encounter.result == nil, !shownBroken, !busy, let action = encounter.intentAction {
                        // Owner QA 2026-10-16: the move is never announced; Analyze reads it once. The lasting tell is his pattern.
                        HStack(spacing: 6) {
                            Image(systemName: AttributeGlyph.symbol(for: "knowledge")).font(HeroFont.label)
                            Text("READ · \(action.intent ?? action.telegraph)").font(action.deflectable ? HeroFont.headline : HeroFont.captionMedium)
                        }
                        .foregroundStyle(action.deflectable ? NeoTokyo.Attribute.color(for: "strength") : NeoTokyo.Attribute.color(for: "knowledge"))
                        .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                        .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                        .id(action.telegraph).transition(.scale(scale: 1.15).combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.12)
                .animation(.easeOut(duration: 0.2), value: busy)
                .animation(.easeOut(duration: 0.2), value: line)
            .animation(.easeOut(duration: 0.2), value: narration)
            .animation(.easeOut(duration: 0.2), value: readNext)
            .animation(.easeOut(duration: 0.3), value: phaseBanner)
            }
            .animation(.easeOut(duration: 0.35), value: dim)
            .offset(stageShake)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(reduceMotion ? nil : .spring(duration: 0.12, bounce: 0.4), value: stageShake)
            .animation(.easeOut(duration: 0.25), value: bossAura)
            .animation(reduceMotion ? nil : .spring(duration: 0.16, bounce: 0.15), value: heroLunge)
            .animation(reduceMotion ? nil : .spring(duration: 0.16, bounce: 0.15), value: bossLunge)
            .animation(.easeOut(duration: 0.12), value: heroPhase)
            .animation(.easeOut(duration: 0.1), value: bossHit)
            .animation(.easeOut(duration: 0.1), value: heroHit)
            .animation(.easeOut(duration: 0.25), value: outline)
            .animation(.easeOut(duration: 0.2), value: pop?.id)
        }
    }

    /// Feedback at its anchor (brief P0-4), clamped inside the stage so nothing clips at the edges.
    private func popView(_ pop: Pop, size: CGSize, heroAnchor: CGPoint, bossAnchor: CGPoint, floorY: CGFloat) -> some View {
        let margin: CGFloat = pop.big ? 110 : 80
        let raw: CGPoint
        switch pop.anchor {
        case .bossTorso: raw = CGPoint(x: bossAnchor.x - 24, y: floorY - 150)
        case .heroTorso: raw = CGPoint(x: heroAnchor.x + 16, y: floorY - 120)
        case .playerStatus: raw = CGPoint(x: heroAnchor.x + 40, y: size.height - 26)
        case .bossCenter: raw = CGPoint(x: bossAnchor.x - 30, y: floorY - 105)
        }
        return VStack(spacing: 2) {
            Text(pop.text).font(pop.big ? HeroFont.statXL : HeroFont.title).foregroundStyle(pop.color)
            if let sub = pop.sub { Text(sub).font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.primary) }
        }
        .multilineTextAlignment(.center)
        .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 6)
        .frame(width: 2 * margin)
        .position(x: min(max(raw.x, margin), size.width - margin), y: min(max(raw.y, 30), size.height - 16))
        .id(pop.id)
        .transition(.scale(scale: 1.5).combined(with: .opacity))
    }

    /// Colossus's layers (his persistent intensity, the aura while he moves, the Analyze outline, the state sprite, the hit
    /// flash, the scan). Its own function: the stage body was past what the type checker takes.
    private func bossLayers(bossAnchor: CGPoint, floorY: CGFloat, size: CGSize) -> some View {
        ZStack {
            // P1-6: a persistent intensity that grows with every MORE (never his size).
            placed(NeoTokyo.Attribute.color(for: "strength").mask { SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale) }.blur(radius: 8).opacity(min(0.5, 0.16 * Double(moreCount))),
                   canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            placed(bossAuraColor.mask { SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale) }.blur(radius: 14).opacity(bossAura * 0.6),
                   canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            placed(bossAuraColor.mask { SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale) }.blur(radius: 4).opacity(bossAura * 0.8),
                   canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            placed(NeoTokyo.Attribute.color(for: "knowledge").mask { SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale) }.blur(radius: 4).opacity(outline),
                   canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            placed(SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            placed(Color.white.mask { SpritePlayer(assetSetID: bossSet, animation: bossAnim, scale: Self.scale) }.opacity(bossHit), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: bossAnchor)
            if let scan {
                Rectangle().fill(NeoTokyo.Attribute.color(for: "knowledge")).frame(width: 2, height: 160 * Self.scale)
                    .shadow(color: NeoTokyo.Attribute.color(for: "knowledge"), radius: 6)
                    .position(x: bossAnchor.x - 60 + scan * 120, y: floorY - 80 * Self.scale)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// The hero's layers: the real sprite and its white-out, the afterimage, the master as a light silhouette, the beads, the eyes.
    private func heroLayers(heroAnchor: CGPoint, floorY: CGFloat, size: CGSize) -> some View {
        ZStack {
            // Hero: the real sprite, its white-out, the action master and its white-out, the eyes.
            if let recipe = state.recipe {
                let realVisible = heroPhase == .idle || heroPhase == .eyes || heroPhase == .whiteReal
                placed(CharacterView(recipe: recipe, scale: Self.scale, ascension: state.ascensionTier, lag: CGSize(width: -heroLunge * 0.6, height: 0)).opacity(realVisible ? 1 : 0),
                       canvas: Self.heroCanvas, pivot: Self.heroPivot, at: heroAnchor)
                placed(Color.white.mask { LayeredCharacterView(recipe: recipe, scale: Self.scale, ascension: 0) }.opacity(heroPhase == .whiteReal ? 1 : (realVisible ? heroHit : 0)),
                       canvas: Self.heroCanvas, pivot: Self.heroPivot, at: heroAnchor)
            }
            // Doc 38: at any tier the action leaves one short afterimage of the master in the tier colour, trailing the lunge.
            if state.ascensionTier >= 1, afterAlpha > 0 {
                placed(NeoTokyo.Ascension.color(forTier: state.ascensionTier).mask { SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale) }.opacity(afterAlpha),
                       canvas: Self.combatCanvas, pivot: Self.combatPivot, at: CGPoint(x: size.width * Self.heroX + afterX, y: floorY))
            }
            let masterVisible = heroPhase == .action || heroPhase == .whiteAction
            // Owner notes 2026-10-16: through the action the master is a light silhouette, not a sprite: a diffuse
            // anime bloom in widening passes behind it, a white-hot core with a wash of the verb's colour, and
            // beads of light drifting off the edge. The master's pixels are never shown on their own.
            let masterSprite = SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale)
            placed(actionColor.mask { masterSprite }.blur(radius: 22).opacity(masterVisible ? 0.55 : 0), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
            placed(actionColor.mask { masterSprite }.blur(radius: 10).opacity(masterVisible ? 0.75 : 0), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
            placed(actionColor.mask { masterSprite }.blur(radius: 3).opacity(masterVisible ? 0.95 : 0), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
            placed(Color.white.mask { masterSprite }.opacity(masterVisible ? 0.96 : 0), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
            placed(actionColor.mask { masterSprite }.opacity(heroPhase == .action ? 0.22 : 0), canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
            if heroPhase == .action, !reduceMotion {
                // Center's energy contracts (P0-1): the beads drift inward instead of off the edge.
                GlowBeads(color: actionColor, inward: heroAction == .center).frame(width: 150, height: 240).position(x: heroAnchor.x + 10, y: floorY - 110).allowsHitTesting(false)
            }
            if heroPhase == .eyes || heroPhase == .whiteReal {
                Capsule().fill(actionColor).frame(width: 8, height: 3).shadow(color: actionColor, radius: 5).shadow(color: .white, radius: 2)
                    .position(x: heroAnchor.x + 5, y: floorY - 97 * Self.scale)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var pressureVignette: some View {
        RoundedRectangle(cornerRadius: 0).strokeBorder(NeoTokyo.Attribute.color(for: "strength").opacity(0.14 * Double(shownPressure)), lineWidth: 28)
            .blur(radius: 18).ignoresSafeArea().allowsHitTesting(false)
            .animation(.easeOut(duration: 0.4), value: shownPressure)
    }

    // MARK: player panel

    private var playerPanel: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.recipe?.name ?? "You").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                    Text("STAMINA").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    Spacer()
                    if shownPressure > 0 {
                        Text("PRESSURE ×\(shownPressure)").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Attribute.color(for: "strength")).transition(.opacity)
                    }
                    Text("\(max(0, Int(shownPlayer.rounded()))) / \(Int(encounter.playerStaminaMax.rounded()))").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
                        .contentTransition(.numericText(value: shownPlayer))
                }
                bar(value: shownPlayer / encounter.playerStaminaMax, tint: NeoTokyo.Hierarchy.primary)
            }
            .containerRelativeFrame(.horizontal, count: 10, span: 7, spacing: 0)
            .frame(maxWidth: .infinity, alignment: .trailing)
            if let hint {
                Text(hint).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).transition(.opacity)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: NeoTokyo.Spacing.sm), GridItem(.flexible())], spacing: NeoTokyo.Spacing.sm) {
                ForEach(CombatAction.allCases, id: \.self) { action in
                    Button { perform(action) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: AttributeGlyph.symbol(for: action.attributeID))
                            Text(action.rawValue.uppercased())
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Attribute.color(for: action.attributeID.rawValue)))
                    .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous)
                        .stroke(NeoTokyo.Hierarchy.primary.opacity(shownBroken && action == .attack && !busy ? 0.9 : 0), lineWidth: 1.5))
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(shownBroken && action == .attack && !busy ? 0.35 : 0), radius: 12)
                    .disabled(busy || encounter.result != nil)
                }
            }
            if fight.rehearsal { rehearsalRow }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.top, NeoTokyo.Spacing.md)
        .padding(.bottom, NeoTokyo.Spacing.xl)
        .animation(.easeOut(duration: 0.2), value: shownPressure)
        .animation(.easeOut(duration: 0.2), value: hint)
    }

    /// Dev: play Colossus's states and the hit reactions without the engine, to review the transitions.
    private var rehearsalRow: some View {
        HStack(spacing: NeoTokyo.Spacing.xs) {
            ForEach(["crush", "more", "break", "recover"], id: \.self) { key in
                Button(key.uppercased()) { rehearse(key) }.buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Text.secondary)).disabled(busy)
            }
        }
        .font(HeroFont.label)
    }

    private func bar(value: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NeoTokyo.Surface.overlay)
                Capsule().fill(tint).frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.easeOut(duration: 0.3), value: value)
            }
        }
        .frame(height: 10)
    }

    // MARK: result

    private func resultCard(_ result: CombatResult) -> some View {
        VStack(spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: result == .won ? (boss.dialogue["defeated_title"] ?? "\(boss.displayName) defeated") : "Not this time")
            Text(result == .won ? (boss.dialogue["defeated_line"] ?? "\(encounter.turn) turns. He felt every one.") : (state.bossLossLine(boss) ?? "He is still standing."))
                .font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if result != .won { Text("Cairon").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary) }
            Button(result == .won ? "Continue" : "Leave for now") { onFinish(result) }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(NeoTokyo.Spacing.lg)
        .glass(tint: NeoTokyo.Surface.raised)
        .padding(NeoTokyo.Spacing.xl)
    }

    // MARK: choreography (doc 36 §18: ~1.3 s per player action; boss ~0.8 s)

    private func perform(_ action: CombatAction) {
        guard !busy, encounter.result == nil else { return }
        busy = true
        readNext = false
        let events = encounter.step(action)
        let split = events.firstIndex { if case .bossAttack = $0 { return true }; if case .bossLoad = $0 { return true }; if case .pressure = $0 { return true }; if case .bossRecovered = $0 { return true }; return false } ?? events.count
        let playerEvents = Array(events[..<split]), bossEvents = Array(events[split...])
        Task { @MainActor in
            await heroPowerUp(action)
            for event in playerEvents { await play(event) }
            // Guard (brief P0-2): Colossus moves, the player absorbs or deflects; the brace holds until his hit lands.
            if encounter.result == .won {
                guardPending = nil   // the pose holds while he goes down (P1-8); `victory()` brings you back
            } else if action == .`guard`, guardPending != nil, !bossEvents.isEmpty {
                for event in bossEvents { await play(event) }
                guardPending = nil
                await heroPowerDown()
            } else {
                guardPending = nil
                await heroPowerDown()
                for event in bossEvents { await play(event) }
            }
            await pause(150)
            pop = nil
            if encounter.result == .won { await victory() }
            else if encounter.result == nil, !phaseShown, let at = boss.phaseAt, shownBoss <= encounter.bossStaminaMax * at { await phaseBeat() }
            if let result = encounter.result { state.recordBossAttempt(boss, result: result); await pause(200) }
            busy = false
        }
    }

    /// P1-7: once, at the phase share. He stops, finishes nothing, looks at you, says it; the aura climbs; the title; on.
    private func phaseBeat() async {
        phaseShown = true
        bossAnim = "idle"; await pause(350)
        line = boss.dialogue["phase_two"]; await pause(500)
        bossAuraColor = NeoTokyo.Attribute.color(for: "strength"); bossAura = 1; dim = 0.3
        if !reduceMotion { stageShake = CGSize(width: 3, height: -2); await pause(90); stageShake = .zero }
        phaseBanner = boss.dialogue["phase_two_title"] ?? "PHASE II"
        moreCount = max(moreCount, 1)
        await pause(1400)
        phaseBanner = nil; line = nil; bossAura = 0; dim = 0
        await pause(250)
    }

    /// P1-8: the last hit has landed and the recoil played. He goes to his exhausted pose, the room goes quiet, you
    /// return to idle, then the card (about two seconds from the hit).
    private func victory() async {
        defeated = true
        await pause(250)
        bossAnim = "broken"; bossAura = 0; moreCount = 0
        await pause(500)
        dim = 0.3; narration = nil; line = nil
        await pause(500)
        await heroPowerDown()
        await pause(300)
    }

    /// Real idle → eyes → white real → white master → the master in its glow, moved into its action.
    private func heroPowerUp(_ action: CombatAction) async {
        heroAction = action
        heroPhase = .eyes; await pause(110)
        heroPhase = .whiteReal; await pause(170)
        heroPhase = .whiteAction; await pause(90)
        heroPhase = .action
        if !reduceMotion {
            afterX = heroLunge
            // Owner brief 2026-10-16 (P0-1): only Attack moves toward him; Guard braces in place, Analyze and Center hold.
            switch action {
            case .attack: heroLunge = 72
            case .center: heroLunge = 0
            case .`guard`: heroLunge = -4
            case .analyze: heroLunge = 0
            }
            if let profile = CharacterKitStore.ascensionProfile(tier: state.ascensionTier) {
                afterAlpha = profile.afterimageAlpha
                withAnimation(.easeOut(duration: 0.15 + 0.12 * Double(state.ascensionTier))) { afterAlpha = 0 }
            }
        }
        await pause(170)
    }
    /// The reverse: back to position, white master → white real → the real idle.
    private func heroPowerDown() async {
        heroLunge = 0; await pause(180)
        heroPhase = .whiteAction; await pause(90)
        heroPhase = .whiteReal; await pause(140)
        heroPhase = .idle; await pause(120)
    }

    private func play(_ event: CombatEvent) async {
        switch event {
        case let .damage(v, critical):
            bossLunge = reduceMotion ? 0 : (critical ? 12 : 8)
            await hit(onBoss: true, text: critical ? "CRITICAL \(Int(v.rounded()))" : "\(Int(v.rounded()))", color: critical ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary, big: critical, at: critical ? .bossCenter : .bossTorso)
            shownBoss = max(0, shownBoss - v); bossLunge = 0
            await pause(120)
        case let .guarded(reduction):
            // The brace is the whole animation; the ripple and the number wait for his hit (P0-1, P0-2).
            guardPending = reduction
            pop = Pop(text: "GUARD", onBoss: false, color: NeoTokyo.Attribute.color(for: "endurance"), big: false)
            await pause(260)
        case let .analyzed(bd):
            if bd > 0 {
                scan = 0; outline = 1
                withAnimation(.easeInOut(duration: 0.45)) { scan = 1 }
                await pause(300)
                pop = Pop(text: "ANALYZE", onBoss: true, color: NeoTokyo.Attribute.color(for: "knowledge"), big: false)
                await pause(220)
                scan = nil; outline = 0
                readNext = true
            } else {
                pop = Pop(text: "…", onBoss: true, color: NeoTokyo.Text.secondary, big: false); await pause(260)
            }
        case let .breakDamage(amount, left):
            breakPop = "−\(String(format: amount == amount.rounded() ? "%.0f" : "%.1f", amount))"
            shownBreak = left; await pause(320); breakPop = nil
        case .broken:
            shatter = true; shownBroken = true; bossAnim = "broken"; bossAuraColor = NeoTokyo.Hierarchy.primary; bossAura = 0.8
            await hit(onBoss: true, text: "BROKEN", color: NeoTokyo.Hierarchy.primary, big: true, at: .bossCenter)
            shatter = false; bossAura = 0.3
            showHint("break")
        case let .centered(cleared, recovered):
            ring = Ring(color: NeoTokyo.Attribute.color(for: "mindfulness"), inward: true)
            await pause(200)
            shownPressure = max(0, shownPressure - cleared); shownPlayer = min(encounter.playerStaminaMax, shownPlayer + recovered)
            if cleared > 0 {
                let sub = shownPressure == 0 && !clearExplained ? boss.tutorial["pressure_cleared"] : nil
                if sub != nil { clearExplained = true }
                pop = Pop(text: shownPressure == 0 ? "PRESSURE CLEARED" : "−\(cleared) PRESSURE", at: .playerStatus, color: NeoTokyo.Attribute.color(for: "mindfulness"), big: false, sub: sub)
            } else {
                pop = Pop(text: "+\(Int(recovered.rounded()))", onBoss: false, color: NeoTokyo.Attribute.color(for: "mindfulness"), big: false)
            }
            await pause(320)
        case .bossRecovered:
            shownBroken = false; shownBreak = encounter.breakMax; bossAnim = "idle"; bossAura = 0
            await pause(260)
        case let .bossAttack(name, _, taken, deflected):
            narration = boss.actions[name]?.telegraph
            bossAnim = "attack"; bossAuraColor = NeoTokyo.Attribute.color(for: "strength"); bossAura = 1; await pause(140)
            if !reduceMotion { bossLunge = -60 }
            await pause(160)
            if deflected {
                ring = Ring(color: NeoTokyo.Attribute.color(for: "endurance"), inward: false)
                await hit(onBoss: false, text: "DEFLECT", color: NeoTokyo.Attribute.color(for: "endurance"), big: true)
            } else if let reduction = guardPending {
                // Impact absorption: the ripple and the reduction at the moment his hit lands on the brace.
                ring = Ring(color: NeoTokyo.Attribute.color(for: "endurance"), inward: false)
                pop = Pop(text: "GUARD \(Int((reduction * 100).rounded()))%", onBoss: false, color: NeoTokyo.Attribute.color(for: "endurance"), big: false)
                await pause(220)
            }
            await hit(onBoss: false, text: "\(Int(taken.rounded()))", color: NeoTokyo.Text.primary, big: false)
            shownPlayer = max(0, shownPlayer - taken)
            bossLunge = 0; bossAura = 0; await pause(160)
            bossAnim = shownBroken ? "broken" : "idle"
            narration = nil
            if taken > encounter.playerStaminaMax * 0.15 { showHint("guard") }
        case let .bossLoad(m):
            narration = boss.actions["load"]?.telegraph
            bossAnim = "buff"; bossAuraColor = NeoTokyo.Text.secondary; bossAura = 0.7
            pop = Pop(text: "LOADED ×\(String(format: "%.1f", m))", at: .bossTorso, color: NeoTokyo.Text.secondary, big: false)
            await pause(420); bossAura = 0; bossAnim = "idle"; narration = nil
        case let .pressure(stacks):
            // P1-6: the buff pose, the room darkens, his outline flares, MORE, then the Pressure lands on you.
            narration = boss.actions["more"]?.telegraph
            bossAnim = "buff"; bossAuraColor = NeoTokyo.Attribute.color(for: "strength"); bossAura = 1; dim = 0.3
            if !reduceMotion { stageShake = CGSize(width: 2, height: -1) }
            await pause(120); stageShake = .zero
            pop = Pop(text: "MORE", at: .bossCenter, color: NeoTokyo.Attribute.color(for: "strength"), big: true)
            await pause(420)
            moreCount += 1; shownPressure = stacks
            let sub = pressureExplained ? nil : boss.tutorial["pressure_first"]
            pressureExplained = true
            pop = Pop(text: "PRESSURE ×\(stacks)", at: .playerStatus, color: NeoTokyo.Attribute.color(for: "strength"), big: false, sub: sub)
            await pause(sub == nil ? 380 : 700); bossAura = 0; dim = 0; bossAnim = "idle"; narration = nil
            showHint("pressure")
        case let .dialogue(key):
            if let text = boss.dialogue[key] { line = text; await pause(650); line = nil }
        case .result:
            await pause(100)
        }
    }

    /// Flash, shake, a white hit on the target, the number. Flash sensitivity: every hit also has a sprite state and text.
    private func hit(onBoss: Bool, text: String, color: Color, big: Bool, at anchor: PopAnchor? = nil) async {
        // Every landed hit, from either side, shakes the whole stage (owner 2026-10-16); the target also recoils 3–6 px
        // (6–12 pt at the stage scale) and the frame holds ~70 ms before anything else moves (brief P0-2).
        if !reduceMotion {
            flash = big ? 0.35 : 0.2; shake = onBoss ? 7 : 0; stageShake = CGSize(width: big ? 7 : 4, height: big ? -3 : -2)
            if !onBoss { heroLunge -= 10 }
        }
        if onBoss { bossHit = 1 } else { heroHit = 1 }
        pop = Pop(text: text, at: anchor ?? (onBoss ? .bossTorso : .heroTorso), color: color, big: big)
        await pause(70)
        if !reduceMotion { stageShake = CGSize(width: big ? -5 : -3, height: 1) }
        withAnimation(.easeOut(duration: 0.2)) { flash = 0; shake = 0 }
        await pause(60)
        stageShake = .zero
        bossHit = 0; heroHit = 0
        if !reduceMotion, !onBoss { heroLunge += 10 }
        await pause(big ? 400 : 280)
    }

    private func rehearse(_ key: String) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            switch key {
            case "crush": await play(.bossAttack(name: "crush", incoming: 20, taken: 12, deflected: false))
            case "more": await play(.pressure(stacks: min(3, shownPressure + 1)))
            case "break": await play(.broken(cancelled: nil))
            default: await play(.bossRecovered)
            }
            await pause(150); pop = nil; busy = false
        }
    }

    private func showHint(_ key: String) {
        guard !shownHints.contains(key), let text = boss.tutorial[key] else { return }
        shownHints.insert(key); hint = text
        if key == "attack" { Task { @MainActor in await pause(4000); if hint == text { hint = boss.tutorial["analyze"] } } }
    }
    private func pause(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
}

/// Beads of light drifting off a glowing silhouette (owner note 2026-10-16): small dots on an ellipse around the
/// action master, a few with a cross flare, short lives, drifting outward. Procedural; no texture.
private struct GlowBeads: View {
    let color: Color
    var inward = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height * 0.55
                for i in 0..<22 {
                    let life = 0.45 + Double(i % 5) * 0.05
                    let raw = ((t * 1.3 + Double(i) * 0.37) / life).truncatingRemainder(dividingBy: 1)
                    let phase = inward ? 1 - raw : raw
                    let angle = Double(i) * 0.9 + sin(t * 0.7 + Double(i)) * 0.4
                    let rx = size.width * 0.28 + phase * 22, ry = size.height * 0.42 + phase * 10
                    let x = cx + cos(angle) * rx, y = cy + sin(angle) * ry - phase * 12
                    let alpha = phase < 0.2 ? phase / 0.2 : 1 - (phase - 0.2) / 0.8
                    let big = i % 3 == 0
                    let dot = CGRect(x: x - (big ? 2 : 1), y: y - (big ? 2 : 1), width: big ? 4 : 2, height: big ? 4 : 2)
                    ctx.fill(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(color.opacity(0.35 * alpha)))
                    ctx.fill(Path(ellipseIn: dot), with: .color((i % 2 == 0 ? Color.white : color).opacity(alpha)))
                    if i % 4 == 0 {
                        ctx.fill(Path(CGRect(x: x - 4, y: y - 0.5, width: 8, height: 1)), with: .color(Color.white.opacity(0.7 * alpha)))
                        ctx.fill(Path(CGRect(x: x - 0.5, y: y - 4, width: 1, height: 8)), with: .color(Color.white.opacity(0.7 * alpha)))
                    }
                }
            }
        }
    }
}

/// Guard ripple (outward) and Center pulse (inward): one stroked ring that scales and fades, then removes itself.
private struct RingView: View {
    let color: Color
    let inward: Bool
    @State private var progress = 0.0
    var body: some View {
        Circle().strokeBorder(color, lineWidth: 3)
            .scaleEffect(inward ? 1.5 - progress * 1.2 : 0.3 + progress * 1.3)
            .opacity(1 - progress)
            .onAppear { withAnimation(.easeOut(duration: 0.5)) { progress = 1 } }
            .allowsHitTesting(false)
    }
}

/// Tier-2 Ascension: a few sparse motes drifting up around the hero (doc 36 §20).
private struct AscensionParticles: View {
    let color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<6 {
                    let phase = (t * 0.25 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                    let x = size.width * (0.15 + 0.7 * ((Double(i) * 0.37 + sin(t * 0.6 + Double(i)) * 0.05).truncatingRemainder(dividingBy: 1)))
                    let y = size.height * (1 - phase)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9 * (1 - phase))))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
