import SwiftUI
import HeroDomain
import HeroContent

/// Doc 36 §33 combat screen, first playable (doc 37). The engine decides; this plays its events in order at a
/// fixed beat so the owner can feel the pace before the master action sprites and the VFX library land. Hero
/// left, boss right on the area floor; Stamina and Break above the boss, Stamina and Pressure above the actions;
/// the telegraph sits between the two. Numbers pop at the target; a white flash marks a hit; Reduce Motion keeps
/// the text and drops the movement.
struct BossFight: Identifiable {
    let encounter: BossEncounter
    let milestone: Milestone?
    var id: String { encounter.boss.id.rawValue }
}

struct BossView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fight: BossFight
    let onFinish: (CombatResult) -> Void

    @State private var encounter: BossEncounter
    @State private var busy = false
    @State private var heroLunge: CGFloat = 0
    @State private var bossLunge: CGFloat = 0
    @State private var heroGlow: Color? = nil
    @State private var flash = 0.0
    @State private var shake: CGFloat = 0
    @State private var pop: Pop? = nil
    @State private var line: String? = nil
    @State private var hint: String? = nil
    @State private var shownHints: Set<String> = []

    struct Pop: Identifiable { let id = UUID(); let text: String; let onBoss: Bool; let color: Color; let big: Bool }

    init(fight: BossFight, onFinish: @escaping (CombatResult) -> Void) {
        self.fight = fight; self.onFinish = onFinish; _encounter = State(initialValue: fight.encounter)
    }

    private var boss: BossDefinition { encounter.boss }
    private var bossCharacter: ContentBundle.Character? { state.bundle.character(boss.characterID) }
    private var backdrop: BackdropID {
        let id: BackdropID = "backdrop.colossus_gym.interior_01"
        return BackdropID(state.bundle.backdrop(id)?.assetSetID.rawValue ?? id.rawValue)
    }
    private var bossSprite: AssetSetID? {
        let key = encounter.isBroken ? "broken" : "idle"
        return boss.assets[key].map { AssetSetID($0) } ?? bossCharacter?.spriteAssetSetID
    }

    var body: some View {
        VStack(spacing: 0) {
            bossPanel
            stage
            playerPanel
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .overlay { Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false) }
        .overlay { if let result = encounter.result { resultCard(result).transition(.scale(scale: 0.92).combined(with: .opacity)) } }
        .animation(.easeOut(duration: 0.25), value: encounter.result)
        .onAppear { showHint("attack") }
    }

    // MARK: boss panel

    private var bossPanel: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(boss.displayName).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                Text("\(max(0, Int(encounter.bossStamina.rounded())))").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.primary)
            }
            bar(value: encounter.bossStamina / encounter.bossStaminaMax, tint: NeoTokyo.Text.primary)
            HStack(spacing: 6) {
                Text("BREAK").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                ForEach(0..<Int(encounter.breakMax.rounded()), id: \.self) { i in
                    Image(systemName: Double(i) < encounter.breakNow.rounded(.up) && !encounter.isBroken ? "diamond.fill" : "diamond")
                        .font(HeroFont.label).foregroundStyle(encounter.isBroken ? NeoTokyo.Hierarchy.primary : NeoTokyo.Attribute.color(for: "knowledge"))
                }
                if encounter.isBroken { Text("BROKEN").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.primary) }
                Spacer()
            }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.top, DeviceInsets.top + NeoTokyo.Spacing.sm)
        .padding(.bottom, NeoTokyo.Spacing.sm)
    }

    // MARK: stage

    private static let heroWidth: CGFloat = 64 * HomeView.characterScale
    private var stage: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                BackdropImage(assetSetID: backdrop)
                HStack(alignment: .bottom) {
                    if let recipe = state.recipe {
                        CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.ascensionTier)
                            .shadow(color: (heroGlow ?? NeoTokyo.Hierarchy.primary).opacity(heroGlow == nil ? 0.3 : 0.95), radius: heroGlow == nil ? 12 : 28)
                            .offset(x: heroLunge)
                    }
                    Spacer()
                    if let sprite = bossSprite {
                        SpritePlayer(assetSetID: sprite, animation: "still", scale: HomeView.characterScale)
                            .opacity(encounter.isBroken ? 0.75 : 1)
                            .rotationEffect(.degrees(encounter.isBroken ? 8 : 0), anchor: .bottom)
                            .offset(x: bossLunge + shake)
                    }
                }
                .padding(.horizontal, NeoTokyo.Spacing.xl)
                .padding(.bottom, geo.size.height * 0.07)
                // Telegraph: impossible to miss, between the two.
                VStack {
                    Spacer()
                    if let line {
                        Text("“\(line)”").font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay)
                            .transition(.opacity)
                    }
                    if encounter.result == nil, !encounter.isBroken, let action = encounter.intentAction {
                        Text(action.telegraph).font(action.damage > 0 && action.deflectable ? HeroFont.headline : HeroFont.captionMedium)
                            .foregroundStyle(action.deflectable ? NeoTokyo.Attribute.color(for: "strength") : NeoTokyo.Text.secondary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.xs)
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                            .id(action.telegraph)
                            .transition(.scale(scale: 1.15).combined(with: .opacity))
                    }
                    Spacer().frame(height: geo.size.height * 0.45)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.2), value: encounter.intent)
                if let pop {
                    Text(pop.text).font(pop.big ? HeroFont.statXL : HeroFont.title).foregroundStyle(pop.color)
                        .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 6)
                        .position(x: pop.onBoss ? geo.size.width * 0.72 : geo.size.width * 0.28, y: geo.size.height * 0.35)
                        .id(pop.id)
                        .transition(.scale(scale: 1.5).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.2), value: heroLunge)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.2), value: bossLunge)
            .animation(.easeOut(duration: 0.2), value: pop?.id)
            .animation(.easeOut(duration: 0.2), value: line)
        }
    }

    // MARK: player panel

    private var playerPanel: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("STAMINA").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                Spacer()
                if encounter.pressure > 0 {
                    Text("PRESSURE ×\(encounter.pressure)").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Attribute.color(for: "strength"))
                        .transition(.opacity)
                }
                Text("\(max(0, Int(encounter.playerStamina.rounded()))) / \(Int(encounter.playerStaminaMax.rounded()))").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
            }
            bar(value: encounter.playerStamina / encounter.playerStaminaMax, tint: NeoTokyo.Hierarchy.primary)
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
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.top, NeoTokyo.Spacing.md)
        .padding(.bottom, NeoTokyo.Spacing.xl)
        .animation(.easeOut(duration: 0.2), value: encounter.pressure)
        .animation(.easeOut(duration: 0.2), value: hint)
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

    // MARK: choreography (doc 36 §18: fast)

    private func perform(_ action: CombatAction) {
        guard !busy, encounter.result == nil else { return }
        busy = true
        let events = encounter.step(action)
        Task { @MainActor in
            heroGlow = NeoTokyo.Attribute.color(for: action.attributeID.rawValue)
            await pause(120)
            if action == .attack && !reduceMotion { heroLunge = 90 }
            if action == .center && !reduceMotion { heroLunge = -8 }
            await pause(160)
            for event in events { await play(event, action: action) }
            heroLunge = 0; heroGlow = nil; bossLunge = 0
            await pause(200)
            pop = nil
            busy = false
            if let result = encounter.result {
                await pause(250)
                state.recordBossAttempt(boss, result: result)
            }
        }
    }

    private func play(_ event: CombatEvent, action: CombatAction) async {
        switch event {
        case let .damage(v, critical):
            await hit(onBoss: true, text: critical ? "CRITICAL \(Int(v.rounded()))" : "\(Int(v.rounded()))", color: critical ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary, big: critical)
        case let .guarded(reduction):
            pop = Pop(text: "GUARD \(Int((reduction * 100).rounded()))%", onBoss: false, color: NeoTokyo.Attribute.color(for: "endurance"), big: false)
            await pause(300)
        case let .analyzed(bd):
            pop = Pop(text: bd > 0 ? "ANALYZE" : "…", onBoss: true, color: NeoTokyo.Attribute.color(for: "knowledge"), big: false)
            await pause(300)
        case let .breakDamage(_, left):
            if left <= 0 { break }
            await pause(120)
        case .broken:
            await hit(onBoss: true, text: "BROKEN", color: NeoTokyo.Hierarchy.primary, big: true)
            showHint("break")
        case let .centered(cleared, recovered):
            pop = Pop(text: cleared > 0 ? "−\(cleared) PRESSURE" : "+\(Int(recovered.rounded()))", onBoss: false, color: NeoTokyo.Attribute.color(for: "mindfulness"), big: false)
            await pause(350)
        case .bossRecovered:
            await pause(200)
        case let .bossAttack(_, _, taken, deflected):
            if !reduceMotion { bossLunge = -90 }
            await pause(180)
            if deflected { await hit(onBoss: false, text: "DEFLECT", color: NeoTokyo.Attribute.color(for: "endurance"), big: true) }
            await hit(onBoss: false, text: "\(Int(taken.rounded()))", color: NeoTokyo.Text.primary, big: false)
            bossLunge = 0
            if taken > encounter.playerStaminaMax * 0.15 { showHint("guard") }
        case let .bossLoad(m):
            pop = Pop(text: "LOADED ×\(String(format: "%.1f", m))", onBoss: true, color: NeoTokyo.Text.secondary, big: false)
            await pause(350)
        case let .pressure(stacks):
            pop = Pop(text: "PRESSURE ×\(stacks)", onBoss: false, color: NeoTokyo.Attribute.color(for: "strength"), big: false)
            await pause(350)
            showHint("pressure")
        case let .dialogue(key):
            if let text = boss.dialogue[key] { line = text; await pause(700); line = nil }
        case .result:
            await pause(100)
        }
    }

    private func hit(onBoss: Bool, text: String, color: Color, big: Bool) async {
        if !reduceMotion { flash = big ? 0.55 : 0.3; shake = onBoss ? 8 : 0 }
        pop = Pop(text: text, onBoss: onBoss, color: color, big: big)
        await pause(70)
        withAnimation(.easeOut(duration: 0.2)) { flash = 0; shake = 0 }
        await pause(big ? 420 : 300)
    }

    private func showHint(_ key: String) {
        guard !shownHints.contains(key), let text = boss.tutorial[key] else { return }
        shownHints.insert(key); hint = text
        if key == "attack" { Task { @MainActor in await pause(4000); if hint == text { hint = boss.tutorial["analyze"] } } }
    }
    private func pause(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
}
