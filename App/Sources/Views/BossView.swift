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
    @State private var shatter = false
    @State private var ring: Ring? = nil
    @State private var pop: Pop? = nil
    @State private var line: String? = nil
    @State private var hint: String? = nil
    @State private var shownHints: Set<String> = []

    struct Pop: Identifiable { let id = UUID(); let text: String; let onBoss: Bool; let color: Color; let big: Bool }
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

    private var bossPanel: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(boss.displayName).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                Text("\(max(0, Int(shownBoss.rounded())))").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.primary)
                    .contentTransition(.numericText(value: shownBoss))
            }
            bar(value: shownBoss / encounter.bossStaminaMax, tint: NeoTokyo.Text.primary)
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
                Spacer()
            }
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
            let heroAnchor = CGPoint(x: geo.size.width * 0.27 + heroLunge, y: floorY)
            let bossAnchor = CGPoint(x: geo.size.width * 0.73 + bossLunge + shake, y: floorY)
            ZStack {
                BackdropImage(assetSetID: backdrop)
                // Ascension field under the hero's feet (doc 36 §20: the tier modifies the presentation, not the animation).
                if state.ascensionTier >= 1 {
                    Ellipse().fill(NeoTokyo.Hierarchy.primary.opacity(state.ascensionTier >= 2 ? 0.22 : 0.12))
                        .frame(width: 120, height: 18).blur(radius: 10)
                        .position(x: heroAnchor.x, y: floorY - 2)
                    if state.ascensionTier >= 2 { AscensionParticles(color: NeoTokyo.Hierarchy.primary).frame(width: 90, height: 160).position(x: heroAnchor.x, y: floorY - 90) }
                }
                // Colossus: outline glow behind, the state sprite, a white hit flash over it.
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
                // Hero: the real sprite, its white-out, the action master and its white-out, the eyes.
                if let recipe = state.recipe {
                    let realVisible = heroPhase == .idle || heroPhase == .eyes || heroPhase == .whiteReal
                    placed(CharacterView(recipe: recipe, scale: Self.scale, ascension: state.ascensionTier).opacity(realVisible ? 1 : 0),
                           canvas: Self.heroCanvas, pivot: Self.heroPivot, at: heroAnchor)
                    placed(Color.white.mask { LayeredCharacterView(recipe: recipe, scale: Self.scale, ascension: 0) }.opacity(heroPhase == .whiteReal ? 1 : (realVisible ? heroHit : 0)),
                           canvas: Self.heroCanvas, pivot: Self.heroPivot, at: heroAnchor)
                }
                let masterVisible = heroPhase == .action || heroPhase == .whiteAction
                // Owner note 2026-10-16: the master stays a glowing avatar all the way through the action (doc 36 §18
                // "heavily illuminated, near-silhouette"), never a plain bald sprite: a wide colour bloom behind, the
                // master, a heavy white wash, and a thin colour wash on top.
                placed(actionColor.mask { SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale) }
                        .blur(radius: 9).opacity(masterVisible ? 0.95 : 0),
                       canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
                placed(SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale)
                        .shadow(color: actionColor.opacity(0.95), radius: 26).shadow(color: actionColor.opacity(0.7), radius: 8)
                        .opacity(masterVisible ? 1 : 0),
                       canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
                placed(Color.white.mask { SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale) }
                        .opacity(heroPhase == .whiteAction ? 1 : (heroPhase == .action ? 0.72 : 0)),
                       canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
                placed(actionColor.mask { SpritePlayer(assetSetID: heroMasters, animation: heroAction.rawValue, scale: Self.scale) }
                        .opacity(heroPhase == .action ? 0.35 : 0),
                       canvas: Self.combatCanvas, pivot: Self.combatPivot, at: heroAnchor)
                if heroPhase == .eyes || heroPhase == .whiteReal {
                    Capsule().fill(actionColor).frame(width: 8, height: 3).shadow(color: actionColor, radius: 5).shadow(color: .white, radius: 2)
                        .position(x: heroAnchor.x + 5, y: floorY - 97 * Self.scale)
                        .transition(.opacity)
                }
                if let ring {
                    RingView(color: ring.color, inward: ring.inward).frame(width: 150, height: 150).position(x: heroAnchor.x, y: floorY - 70).id(ring.id)
                }
                if let pop {
                    Text(pop.text).font(pop.big ? HeroFont.statXL : HeroFont.title).foregroundStyle(pop.color)
                        .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 6)
                        .position(x: pop.onBoss ? bossAnchor.x : heroAnchor.x, y: geo.size.height * 0.3)
                        .id(pop.id)
                        .transition(.scale(scale: 1.5).combined(with: .opacity))
                }
                // Telegraph and the dialogue banner, between the two.
                VStack(spacing: 6) {
                    if let line {
                        Text("“\(line)”").font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay).transition(.opacity)
                    }
                    if encounter.result == nil, !shownBroken, !busy, let action = encounter.intentAction {
                        Text(action.telegraph).font(action.deflectable ? HeroFont.headline : HeroFont.captionMedium)
                            .foregroundStyle(action.deflectable ? NeoTokyo.Attribute.color(for: "strength") : NeoTokyo.Text.secondary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                            .id(action.telegraph).transition(.scale(scale: 1.15).combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.12)
                .animation(.easeOut(duration: 0.2), value: busy)
                .animation(.easeOut(duration: 0.2), value: line)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(reduceMotion ? nil : .spring(duration: 0.16, bounce: 0.15), value: heroLunge)
            .animation(reduceMotion ? nil : .spring(duration: 0.16, bounce: 0.15), value: bossLunge)
            .animation(.easeOut(duration: 0.12), value: heroPhase)
            .animation(.easeOut(duration: 0.1), value: bossHit)
            .animation(.easeOut(duration: 0.1), value: heroHit)
            .animation(.easeOut(duration: 0.25), value: outline)
            .animation(.easeOut(duration: 0.2), value: pop?.id)
        }
    }

    private var pressureVignette: some View {
        RoundedRectangle(cornerRadius: 0).strokeBorder(NeoTokyo.Attribute.color(for: "strength").opacity(0.14 * Double(shownPressure)), lineWidth: 28)
            .blur(radius: 18).ignoresSafeArea().allowsHitTesting(false)
            .animation(.easeOut(duration: 0.4), value: shownPressure)
    }

    // MARK: player panel

    private var playerPanel: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("STAMINA").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                Spacer()
                if shownPressure > 0 {
                    Text("PRESSURE ×\(shownPressure)").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Attribute.color(for: "strength")).transition(.opacity)
                }
                Text("\(max(0, Int(shownPlayer.rounded()))) / \(Int(encounter.playerStaminaMax.rounded()))").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
                    .contentTransition(.numericText(value: shownPlayer))
            }
            bar(value: shownPlayer / encounter.playerStaminaMax, tint: NeoTokyo.Hierarchy.primary)
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
            Eyebrow(text: result == .won ? "Colossus is down" : "Not this time")
            Text(result == .won ? "\(encounter.turn) turns. He felt every one." : (state.bossLossLine(boss) ?? "He is still standing."))
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
        let events = encounter.step(action)
        let split = events.firstIndex { if case .bossAttack = $0 { return true }; if case .bossLoad = $0 { return true }; if case .pressure = $0 { return true }; if case .bossRecovered = $0 { return true }; return false } ?? events.count
        let playerEvents = Array(events[..<split]), bossEvents = Array(events[split...])
        Task { @MainActor in
            await heroPowerUp(action)
            for event in playerEvents { await play(event) }
            await heroPowerDown()
            for event in bossEvents { await play(event) }
            await pause(150)
            pop = nil
            if let result = encounter.result { state.recordBossAttempt(boss, result: result); await pause(200) }
            busy = false
        }
    }

    /// Real idle → eyes → white real → white master → the master in its glow, moved into its action.
    private func heroPowerUp(_ action: CombatAction) async {
        heroAction = action
        heroPhase = .eyes; await pause(110)
        heroPhase = .whiteReal; await pause(170)
        heroPhase = .whiteAction; await pause(90)
        heroPhase = .action
        if !reduceMotion {
            switch action {
            case .attack: heroLunge = 72
            case .center: heroLunge = -6
            case .`guard`: heroLunge = -10
            case .analyze: heroLunge = 8
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
            bossLunge = reduceMotion ? 0 : 18
            await hit(onBoss: true, text: critical ? "CRITICAL \(Int(v.rounded()))" : "\(Int(v.rounded()))", color: critical ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary, big: critical)
            shownBoss = max(0, shownBoss - v); bossLunge = 0
            await pause(120)
        case let .guarded(reduction):
            ring = Ring(color: NeoTokyo.Attribute.color(for: "endurance"), inward: false)
            pop = Pop(text: "GUARD \(Int((reduction * 100).rounded()))%", onBoss: false, color: NeoTokyo.Attribute.color(for: "endurance"), big: false)
            await pause(360)
        case let .analyzed(bd):
            if bd > 0 {
                scan = 0; outline = 1
                withAnimation(.easeInOut(duration: 0.45)) { scan = 1 }
                await pause(300)
                pop = Pop(text: "ANALYZE", onBoss: true, color: NeoTokyo.Attribute.color(for: "knowledge"), big: false)
                await pause(220)
                scan = nil; outline = 0
            } else {
                pop = Pop(text: "…", onBoss: true, color: NeoTokyo.Text.secondary, big: false); await pause(260)
            }
        case let .breakDamage(_, left):
            shownBreak = left; await pause(100)
        case .broken:
            shatter = true; shownBroken = true; bossAnim = "broken"
            await hit(onBoss: true, text: "BROKEN", color: NeoTokyo.Hierarchy.primary, big: true)
            shatter = false
            showHint("break")
        case let .centered(cleared, recovered):
            ring = Ring(color: NeoTokyo.Attribute.color(for: "mindfulness"), inward: true)
            await pause(200)
            shownPressure = max(0, shownPressure - cleared); shownPlayer = min(encounter.playerStaminaMax, shownPlayer + recovered)
            pop = Pop(text: cleared > 0 ? "−\(cleared) PRESSURE" : "+\(Int(recovered.rounded()))", onBoss: false, color: NeoTokyo.Attribute.color(for: "mindfulness"), big: false)
            await pause(320)
        case .bossRecovered:
            shownBroken = false; shownBreak = encounter.breakMax; bossAnim = "idle"
            await pause(260)
        case let .bossAttack(_, _, taken, deflected):
            bossAnim = "attack"; await pause(140)
            if !reduceMotion { bossLunge = -60 }
            await pause(160)
            if deflected {
                ring = Ring(color: NeoTokyo.Attribute.color(for: "endurance"), inward: false)
                await hit(onBoss: false, text: "DEFLECT", color: NeoTokyo.Attribute.color(for: "endurance"), big: true)
            }
            await hit(onBoss: false, text: "\(Int(taken.rounded()))", color: NeoTokyo.Text.primary, big: false)
            shownPlayer = max(0, shownPlayer - taken)
            bossLunge = 0; await pause(160)
            bossAnim = shownBroken ? "broken" : "idle"
            if taken > encounter.playerStaminaMax * 0.15 { showHint("guard") }
        case let .bossLoad(m):
            bossAnim = "buff"
            pop = Pop(text: "LOADED ×\(String(format: "%.1f", m))", onBoss: true, color: NeoTokyo.Text.secondary, big: false)
            await pause(420); bossAnim = "idle"
        case let .pressure(stacks):
            bossAnim = "buff"; await pause(120)
            shownPressure = stacks
            pop = Pop(text: "PRESSURE ×\(stacks)", onBoss: false, color: NeoTokyo.Attribute.color(for: "strength"), big: false)
            await pause(380); bossAnim = "idle"
            showHint("pressure")
        case let .dialogue(key):
            if let text = boss.dialogue[key] { line = text; await pause(650); line = nil }
        case .result:
            await pause(100)
        }
    }

    /// Flash, shake, a white hit on the target, the number. Flash sensitivity: every hit also has a sprite state and text.
    private func hit(onBoss: Bool, text: String, color: Color, big: Bool) async {
        if !reduceMotion { flash = big ? 0.35 : 0.2; shake = onBoss ? 7 : 0 }
        if onBoss { bossHit = 1 } else { heroHit = 1 }
        pop = Pop(text: text, onBoss: onBoss, color: color, big: big)
        await pause(70)
        withAnimation(.easeOut(duration: 0.2)) { flash = 0; shake = 0 }
        bossHit = 0; heroHit = 0
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
