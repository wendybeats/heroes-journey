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
    enum Step: Int, CaseIterable { case awaken, name, body, skin, hair, primary, secondary, frequency, motivation, health, feedback, bond }

    @State private var step: Step = .awaken
    @State private var name = ""
    @State private var draft = AvatarRecipe(name: "", baseBody: .male, skinPaletteID: "skin.light", hairStyleID: "hair.wolf", hairPaletteID: "hair.black", evolutionID: "ev1_awakened", backdropID: "backdrop.rain_district")
    @State private var dressed = false
    @State private var prefs = GoalPreferences()
    @State private var healthAsked = false

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
    }

    private var questions: some View {
        VStack(spacing: 0) {
            scene
            ScrollView {
                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.lg) {
                    HStack(alignment: .top, spacing: NeoTokyo.Spacing.sm) {
                        if let guide = state.bundle.character("guide.elder"), let set = guide.portraitAssetSetID {
                            PortraitView(assetSetID: set, size: 56)
                                .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                        }
                        Bubble(text: line)
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
                CharacterView(recipe: draft, scale: HomeView.characterScale)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 18)
                    .padding(.bottom, NeoTokyo.Spacing.sm)
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
                draft.baseBody = body
                let styles = options.hairStyles(for: raw)
                if !styles.contains(draft.hairStyleID) { draft.hairStyleID = styles.dropFirst().first ?? styles.first ?? draft.hairStyleID }
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
            // Physical: the fist and the foot in the colours of the two physical attributes.
            AttributeGlyphs(pairs: [("strength", "hand.raised.fingers.spread.fill"), ("endurance", "shoeprints.fill")])
            ChoiceRows(options: [("strength", "Strength training"), ("cardio", "Cardio sports"), ("combat", "Combat sports"), ("mobility", "Mobility / recovery")],
                       selection: Binding(get: { prefs.primaryFamily.rawValue }, set: { prefs.primaryFamily = FamilyID($0) }))
        case .secondary:
            AttributeGlyphs(pairs: [("knowledge", "brain.head.profile"), ("mindfulness", "leaf.fill")])
            ChoiceRows(options: [("learning", "Learning · reading, studying"), ("mindfulness", "Mindfulness · breathwork, stillness, daylight"), ("creativity", "Creativity · art, music, journaling")], selection: $prefs.secondaryInterest)
        case .frequency:
            // Bands map to the generator's weekday pattern: 2, 4, 6 and 7 training days.
            ChoiceRows(options: [("2", "1–3 days"), ("4", "3–5 days"), ("6", "5–7 days"), ("7", "Every day or more")],
                       selection: Binding(get: { String(prefs.trainingDaysPerWeek) }, set: { prefs.trainingDaysPerWeek = Int($0) ?? 4 }))
        case .motivation:
            ChoiceRows(options: [("strength_goal", "Get more fit"), ("energy", "Have more energy"), ("calm", "Be more calm"), ("balance", "Become a more balanced person")],
                       selection: Binding(get: { prefs.motivation ?? "" }, set: { prefs.motivation = $0 }))
        case .health:
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                if state.healthAvailable && !healthAsked {
                    Button("Connect Apple Health") { healthAsked = true; Task { await state.connectHealth() } }
                        .buttonStyle(SecondaryButtonStyle(accent: NeoTokyo.Hierarchy.fallback))
                } else if healthAsked {
                    Text("Asked. Whatever you allowed, I will use; whatever you did not, I will not see.")
                        .font(HeroFont.callout).foregroundStyle(NeoTokyo.Text.secondary)
                } else {
                    Text("Apple Health is not available on this device. Logging by hand works the same.")
                        .font(HeroFont.callout).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
        case .feedback:
            feedback
        }
    }

    /// What sealing the bond grants (owner, 2026-10-02): real numbers, not a preview. The bond event
    /// is created on "Seal the bond"; these are the same points the engine will credit.
    private var feedback: some View {
        var deltas: [AttributeID: Int] = [:]
        if let grant = state.ruleset.bondGrant {
            let primary = BondReference.attribute(forFamily: prefs.primaryFamily.rawValue, ruleset: state.ruleset, fallback: "strength")
            let secondary = BondReference.attribute(forFamily: prefs.secondaryInterest, ruleset: state.ruleset, fallback: "mindfulness")
            deltas[primary, default: 0] += grant.primaryPoints
            deltas[secondary, default: 0] += grant.secondaryPoints
        }
        return VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack {
                ForEach(state.bundle.attributes, id: \.id) { attribute in
                    VStack(spacing: 2) {
                        // Owner QA 2026-10-05: the numbers themselves, not zeros with a badge; the badge still fires.
                        CountingText(value: Double(deltas[attribute.id] ?? 0), font: HeroFont.statSM, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        Text(attribute.displayName).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    .overlay(alignment: .top) {
                        DeltaBadge(delta: deltas[attribute.id] ?? 0, token: 1, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue)).offset(y: -16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, NeoTokyo.Spacing.md)
            Text("The bond gives you this to start. Training moves it far more.")
                .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
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
                .disabled(step == .name && name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                    Button(label) { selection = id }
                        .font(HeroFont.callout)
                        .foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                        .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.sm)
                        .glass(cornerRadius: NeoTokyo.Radius.md, tint: on ? NeoTokyo.Surface.overlay : NeoTokyo.Surface.raised)
                }
            }
        }
    }
}

/// Large tappable rows, one selected (Finch reference 02, doc 23).
struct ChoiceRows: View {
    let options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            ForEach(options, id: \.0) { option in
                let (id, label) = option
                let on = selection == id
                Button { selection = id } label: {
                    HStack {
                        Text(label).font(HeroFont.bodyMedium).foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary)
                        Spacer()
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
