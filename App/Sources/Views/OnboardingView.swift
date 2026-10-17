import SwiftUI
import HeroDomain
import HeroContent

/// Onboarding v2 (doc 22 §4, doc 23, doc 24 step 5): the first story chapter. The character is
/// awake before any question; each screen asks one thing, in one line of the character's voice,
/// and the answer shows on them at once. Answers seed `GoalPreferences`, so the first day's goals
/// are generated from what the user said, and the last screen previews what those goals will do
/// to the attributes before Home (owner, 2026-10-02: "stat feedback before they hit home screen").
/// No attribute is granted here: a preview is a preview; grants come from facts (rule 2).
struct OnboardingView: View {
    @Environment(AppState.self) private var state

    /// `awaken` and `bond` are content chapters (doc 25); the rest are the guide's questions.
    /// Order per owner QA 2026-10-02: skin right after body (higher-tier customisation), hair style and colour on one screen.
    /// Doc 40 #17 (owner 2026-10-17): two category questions after the motivation, `more` and `hard`.
    enum Step: Int, CaseIterable { case awaken, name, body, skin, hair, primary, secondary, frequency, motivation, more, hard, health, feedback, bond }

    @State private var step: Step = .awaken
    @State private var name = ""
    @State private var draft = AvatarRecipe(name: "", baseBody: .male, skinPaletteID: "skin.light", hairStyleID: "hair.wolf", hairPaletteID: "hair.black", evolutionID: "ev1_awakened", backdropID: "backdrop.rain_district")
    @State private var dressed = false
    @State private var prefs = GoalPreferences()
    @State private var healthAsked = false
    /// Doc 40 #11: the bond is a sequence, not a card. 0 nothing, 1 the glow, 2 the first attribute, 3 the second, 4 the seal.
    @State private var bondStage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if step == .awaken, let chapter = state.bundle.chapter("chapter.awakening") {
                StoryView(chapter: chapter, heroRecipe: nil) { step = .name }
            } else if step == .bond, let chapter = state.bundle.chapter("chapter.first_training") {
                StoryView(chapter: chapter, heroRecipe: draft) { finish() }
            } else {
                questions
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
        .onChange(of: step) { _, new in
            guard new == .feedback else { bondStage = 0; return }
            if reduceMotion { bondStage = 4; return }
            bondStage = 0
            Task { @MainActor in
                for (stage, ms) in [(1, 250), (2, 1400), (3, 1300), (4, 900)] {
                    try? await Task.sleep(for: .milliseconds(ms))
                    guard step == .feedback else { return }
                    withAnimation(.easeOut(duration: 0.5)) { bondStage = stage }
                }
            }
        }
    }

    private var questions: some View {
        VStack(spacing: 0) {
            scene
            ScrollView {
                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.lg) {
                    // Owner 2026-10-16: the hero is always on the left, so the guide and his bubble sit to the right.
                    HStack(alignment: .top, spacing: NeoTokyo.Spacing.sm) {
                        Bubble(text: line, trailing: true)
                        if let guide = state.bundle.character("guide.elder"), let set = guide.portraitAssetSetID {
                            PortraitView(assetSetID: set, size: 56)
                                .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                        }
                    }
                    content
                }
                .padding(NeoTokyo.Spacing.lg)
            }
            footer
        }
        .onAppear { if !dressed { draft.equipped = state.bundle.starterEquipment; dressed = true } }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
    }

    // MARK: scene

    private var scene: some View {
        ZStack(alignment: .bottom) {
            BackdropImage(assetSetID: "backdrop.alley_awakening")
            // Until the body is chosen the hero is still the hooded stranger (owner, 2026-10-02); a
            // hood-up idle sprite is an art item, the portrait stands in meanwhile.
            if step.rawValue < Step.body.rawValue, let set = state.bundle.character("hero")?.portraitAssetSetID {
                PortraitView(assetSetID: set, size: 170)
                    .padding(.bottom, NeoTokyo.Spacing.sm)
            } else {
                // The bond glows up on the feedback step (stage 1) and stays lit while the attributes land.
                CharacterView(recipe: draft, scale: HomeView.characterScale)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(bondStage >= 1 ? 0.85 : 0.35), radius: bondStage >= 1 ? 40 : 18)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(bondStage >= 1 ? 0.5 : 0), radius: 14)
                    .padding(.bottom, NeoTokyo.Spacing.sm)
                    .animation(.easeOut(duration: 1.1), value: bondStage >= 1)
            }
            HStack(spacing: 4) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule().fill(s.rawValue <= step.rawValue ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.line).frame(height: 3)
                }
            }
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 360)
        .ignoresSafeArea(edges: .top)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: copy

    private var line: String {
        switch step {
        // The guide asks; the answers rebuild the hero (doc 25: "Do you remember anything about your real, human self?").
        case .awaken, .bond: return ""
        // Owner rewrite 2026-10-05 (docs/31 audit): Cairon asks, never flatters; the questions are about the human.
        case .name: return "Start with the easy part. What's your name?"
        case .body: return "\(name.trimmingCharacters(in: .whitespaces)). Good. Hold onto that. Now, what looks like you?"
        case .skin: return "I can barely see your face in the gloom down here."
        case .hair: return "Do you remember what looks right?"
        case .primary: return "What does your human do when they want to get stronger?"
        case .secondary: return "And outside the body? What do they work on?"
        case .frequency: return "How often do they usually train?"
        case .motivation: return "One harder question. Why did they start?"
        case .more: return "What does your human want more of? Pick any."
        case .hard: return "And what do they find hard to keep up?"
        case .health: return "All right. Let's see if the bond reaches all the way through."
        case .feedback: return "There you are. Let's make the connection permanent."
        }
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        let options = state.bundle.avatarOptions
        switch step {
        case .awaken, .bond:
            EmptyView()
        case .name:
            TextField("Name", text: $name)
                .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                .textInputAutocapitalization(.words)
                .padding(NeoTokyo.Spacing.md)
                .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
        case .body:
            ChoiceRows(options: AvatarRecipe.BaseBody.allCases.map { ($0.rawValue, $0.rawValue.capitalized) }, selection: Binding(get: { draft.baseBody.rawValue }, set: { raw in
                guard let body = AvatarRecipe.BaseBody(rawValue: raw) else { return }
                // Doc 40 bug 2: the two bodies share no hair ids, so the pick carries over by position (wolf cut → ponytail), colour kept.
                let from = options.hairStyles(for: draft.baseBody.rawValue), to = options.hairStyles(for: raw)
                draft.baseBody = body
                if !to.contains(draft.hairStyleID) {
                    if let i = from.firstIndex(of: draft.hairStyleID), i < to.count { draft.hairStyleID = to[i] }
                    else { draft.hairStyleID = to.last ?? draft.hairStyleID }
                }
            }))
        case .skin:
            ChoiceRows(options: options.skinPalettes.map { ($0, options.displayName($0)) }, selection: $draft.skinPaletteID)
        case .hair:
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
                Eyebrow(text: "Style")
                ChoiceChips(options: options.hairStyles(for: draft.baseBody.rawValue).map { ($0, options.displayName($0)) }, selection: $draft.hairStyleID)
                Eyebrow(text: "Colour")
                ChoiceChips(options: options.hairPalettes.map { ($0, options.displayName($0)) }, selection: $draft.hairPaletteID)
            }
        case .primary:
            // Owner QA 2026-10-17 (doc 40 #3): each option carries the attributes its family feeds, from the ruleset's weights.
            ChoiceRows(options: [("strength", "Strength training"), ("cardio", "Cardio sports"), ("combat", "Combat sports"), ("mobility", "Mobility / recovery")],
                       selection: Binding(get: { prefs.primaryFamily.rawValue }, set: { prefs.primaryFamily = FamilyID($0) }), glyphs: familyGlyphs)
        case .secondary:
            ChoiceRows(options: [("learning", "Learning · reading, studying"), ("mindfulness", "Mindfulness · breathwork, stillness, daylight"), ("creativity", "Creativity · art, music, journaling")],
                       selection: $prefs.secondaryInterest, glyphs: familyGlyphs)
        case .frequency:
            // Bands map to the generator's weekday pattern: 2, 4, 6 and 7 training days.
            ChoiceRows(options: [("2", "1–3 days"), ("4", "3–5 days"), ("6", "5–7 days"), ("7", "Every day or more")],
                       selection: Binding(get: { String(prefs.trainingDaysPerWeek) }, set: { prefs.trainingDaysPerWeek = Int($0) ?? 4 }))
        case .motivation:
            ChoiceRows(options: [("strength_goal", "Get more fit"), ("energy", "Have more energy"), ("calm", "Be more calm"), ("balance", "Become a more balanced person")],
                       selection: Binding(get: { prefs.motivation ?? "" }, set: { prefs.motivation = $0 }))
        case .more:
            MultiChoiceRows(options: state.bundle.goalCategories.map { ($0.id, $0.displayName, $0.line) }, selection: $prefs.wantMore)
        case .hard:
            MultiChoiceRows(options: state.bundle.goalCategories.map { ($0.id, $0.displayName, $0.line) }, selection: $prefs.findHard)
        case .health:
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                if state.healthAvailable && !healthAsked {
                    Button("Connect Apple Health") { healthAsked = true; Task { await state.connectHealth() } }
                        .buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Hierarchy.fallback))
                } else if healthAsked {
                    HealthBondCard(error: state.healthSync.lastError)
                } else {
                    Text("Apple Health is not available on this device. Logging by hand works the same.")
                        .font(HeroFont.callout).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
        case .feedback:
            feedback
        }
    }

    /// The attributes a family feeds at a third or more of its weight, as (attribute, symbol) pairs, keyed by family id.
    private var familyGlyphs: [String: [(String, String)]] {
        var out: [String: [(String, String)]] = [:]
        for (family, weights) in state.ruleset.attributeWeightsByFamily {
            out[family] = weights.filter { $0.value >= 0.3 }.sorted { $0.value > $1.value }.map { ($0.key, AttributeGlyph.symbol(for: $0.key)) }
        }
        return out
    }

    /// What sealing the bond grants (owner, 2026-10-02): real numbers, not a preview. The bond event is created on
    /// "Seal the bond"; these are the same points the engine will credit. Doc 40 #11 / answer 5: only the two attributes
    /// that move, landing one at a time with the reason each ("+6 Endurance · from your cardio"), then the seal.
    private var feedback: some View {
        let grant = state.ruleset.bondGrant
        let primary = BondReference.attribute(forFamily: prefs.primaryFamily.rawValue, ruleset: state.ruleset, fallback: "strength")
        let secondary = BondReference.attribute(forFamily: prefs.secondaryInterest, ruleset: state.ruleset, fallback: "mindfulness")
        let familyName = state.bundle.family(prefs.primaryFamily)?.displayName.lowercased() ?? prefs.primaryFamily.rawValue
        let interestName = state.bundle.family(FamilyID(prefs.secondaryInterest))?.displayName.lowercased() ?? prefs.secondaryInterest
        var rows: [(AttributeID, Int, String, Int)] = [(primary, grant?.primaryPoints ?? 0, "from your \(familyName)", 2)]
        if secondary == primary { rows[0] = (primary, rows[0].1 + (grant?.secondaryPoints ?? 0), "from your \(familyName) and your interest in \(interestName)", 2) }
        else { rows.append((secondary, grant?.secondaryPoints ?? 0, "from your interest in \(interestName)", 3)) }
        return VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            ForEach(rows, id: \.0) { row in
                let (attribute, points, reason, stage) = row
                let name = state.bundle.attributes.first { $0.id == attribute }?.displayName ?? attribute.rawValue
                HStack(spacing: NeoTokyo.Spacing.md) {
                    Image(systemName: AttributeGlyph.symbol(for: attribute)).font(HeroFont.headline)
                        .foregroundStyle(NeoTokyo.Attribute.color(for: attribute.rawValue)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("+").font(HeroFont.statSM).foregroundStyle(NeoTokyo.Attribute.color(for: attribute.rawValue))
                            CountingText(value: bondStage >= stage ? Double(points) : 0, font: HeroFont.statSM, color: NeoTokyo.Attribute.color(for: attribute.rawValue))
                            Text(name).font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                        }
                        Text(reason).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    Spacer()
                }
                .opacity(bondStage >= stage ? 1 : 0)
                .offset(y: bondStage >= stage ? 0 : 10)
                .animation(.easeOut(duration: 0.9), value: bondStage >= stage)
            }
            Text("The bond gives you this to start. Training moves it far more.")
                .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                .opacity(bondStage >= 4 ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: bondStage >= 4)
        }
        .card()
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            if step != .name {
                Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .awaken }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 96)
            }
            Button(nextLabel) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((step == .name && name.trimmingCharacters(in: .whitespaces).isEmpty) || (step == .feedback && bondStage < 4))
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.bottom, NeoTokyo.Spacing.md)
    }

    private var nextLabel: String {
        switch step {
        case .health: return healthAsked || !state.healthAvailable ? "Next" : "Not now"
        case .feedback: return "Seal the bond"
        default: return "Next"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next; return }
        finish()
    }

    private func finish() {
        guard let ev = state.bundle.evolution(forLevel: 1), let backdrop = state.bundle.defaultBackdrop else { return }
        var r = draft
        r.name = name.trimmingCharacters(in: .whitespaces); r.evolutionID = ev.id; r.backdropID = backdrop.id
        r.equipped = state.bundle.starterEquipment   // doc 32: the first outfit is items on the canonical body
        state.completeOnboarding(recipe: r, preferences: prefs)
    }
}

/// Owner QA 2026-10-16: once Apple Health has been asked, a card rather than a sentence. What was allowed is not
/// knowable from the prompt (doc 08), so it says connected, not what it can see; a failed request says so.
struct HealthBondCard: View {
    var error: String?
    private var connected: Bool { error == nil }
    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.md) {
            Image(systemName: connected ? "heart.fill" : "heart.slash.fill")
                .font(HeroFont.title)
                .foregroundStyle(connected ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                .frame(width: 52, height: 52)
                .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Apple Health")
                Text(connected ? "Connected" : "Not connected").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Text(connected ? "Workouts and steps reach you here." : "Logging by hand works the same.")
                    .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
            }
            Spacer(minLength: 0)
            if connected {
                Image(systemName: "checkmark.seal.fill").font(HeroFont.headline).foregroundStyle(NeoTokyo.Hierarchy.primary)
            }
        }
        .padding(NeoTokyo.Spacing.md)
        .glass(tint: NeoTokyo.Surface.raised)
        .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous).stroke(NeoTokyo.Hierarchy.primary.opacity(connected ? 0.35 : 0), lineWidth: 1))
        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(connected ? 0.18 : 0), radius: 16)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}

/// The attributes a question feeds, as coloured glyphs (owner QA 2026-10-02).
struct AttributeGlyphs: View {
    @Environment(AppState.self) private var state
    let pairs: [(String, String)]
    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.lg) {
            ForEach(pairs, id: \.0) { pair in
                let (attribute, symbol) = pair
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(HeroFont.headline)
                    Text(state.bundle.attributes.first { $0.id.rawValue == attribute }?.displayName ?? attribute).font(HeroFont.captionMedium)
                }
                .foregroundStyle(NeoTokyo.Attribute.color(for: attribute))
            }
        }
    }
}

/// Compact wrapping chips for a secondary choice (hair style and colour share a screen).
struct ChoiceChips: View {
    let options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NeoTokyo.Spacing.sm) {
                ForEach(options, id: \.0) { option in
                    let (id, label) = option
                    let on = selection == id
                    // Owner QA 2026-10-16 (device): the default button style draws its own capsule inside the glass chip; plain, like the rows.
                    Button(label) { selection = id }
                        .buttonStyle(.plain)
                        .font(HeroFont.callout)
                        .foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                        .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.sm)
                        .glass(cornerRadius: NeoTokyo.Radius.md, tint: on ? NeoTokyo.Surface.overlay : NeoTokyo.Surface.raised)
                }
            }
        }
    }
}

/// Large tappable rows, any number selected (doc 40 #17): a title, a line under it, a check when picked.
struct MultiChoiceRows: View {
    let options: [(String, String, String)]
    @Binding var selection: Set<String>
    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            ForEach(options, id: \.0) { option in
                let (id, label, line) = option
                let on = selection.contains(id)
                Button { if on { selection.remove(id) } else { selection.insert(id) } } label: {
                    HStack(spacing: NeoTokyo.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label).font(HeroFont.bodyMedium).foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary)
                            Text(line).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                        }
                        Spacer()
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(HeroFont.headline).foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.muted)
                    }
                    .padding(NeoTokyo.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .glass(cornerRadius: NeoTokyo.Radius.md, tint: on ? NeoTokyo.Surface.overlay : NeoTokyo.Surface.raised)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Large tappable rows, one selected (Finch reference 02, doc 23).
struct ChoiceRows: View {
    let options: [(String, String)]
    @Binding var selection: String
    /// Doc 40 #3: per-option (attribute, symbol) glyphs, drawn in the attribute colour at the trailing edge.
    var glyphs: [String: [(String, String)]] = [:]
    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            ForEach(options, id: \.0) { option in
                let (id, label) = option
                let on = selection == id
                Button { selection = id } label: {
                    HStack {
                        Text(label).font(HeroFont.bodyMedium).foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary)
                        Spacer()
                        ForEach(glyphs[id] ?? [], id: \.0) { pair in
                            Image(systemName: pair.1).font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Attribute.color(for: pair.0))
                        }
                        if on { Image(systemName: "checkmark").font(HeroFont.headline).foregroundStyle(NeoTokyo.Hierarchy.primary) }
                    }
                    .padding(NeoTokyo.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .glass(cornerRadius: NeoTokyo.Radius.md, tint: on ? NeoTokyo.Surface.overlay : NeoTokyo.Surface.raised)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
