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

    enum Step: Int, CaseIterable { case awaken, name, body, hair, hairColor, skin, primary, secondary, frequency, motivation, health, feedback }

    @State private var step: Step = .awaken
    @State private var name = ""
    @State private var draft = AvatarRecipe(name: "", baseBody: .male, skinPaletteID: "skin.light", hairStyleID: "hair.wolf", hairPaletteID: "hair.black", evolutionID: "ev1_awakened", backdropID: "backdrop.rain_district")
    @State private var prefs = GoalPreferences()
    @State private var healthAsked = false

    var body: some View {
        VStack(spacing: 0) {
            scene
            ScrollView {
                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.lg) {
                    SpeechLine(text: line)
                    content
                }
                .padding(NeoTokyo.Spacing.lg)
            }
            footer
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .animation(.easeOut(duration: 0.25), value: step)
    }

    // MARK: scene

    private var scene: some View {
        ZStack(alignment: .bottom) {
            BackdropImage(assetSetID: "backdrop.rain_district")
            CharacterView(recipe: draft, outfit: state.bundle.evolution(forLevel: 1)?.outfit, scale: HomeView.characterScale)
                .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 18)
                .padding(.bottom, NeoTokyo.Spacing.lg)
            HStack(spacing: 4) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule().fill(s.rawValue <= step.rawValue ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.line).frame(height: 3)
                }
            }
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 300)
        .ignoresSafeArea(edges: .top)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: copy

    private var line: String {
        switch step {
        case .awaken: return "…Where is this. Rain. A city I almost remember. And you. Do I know you?"
        case .name: return "Start with the easy one. What do they call me?"
        case .body: return "Which of these is me? Pick the one that looks right. I will not argue."
        case .hair: return "The hair. I had a feeling about the hair."
        case .hairColor: return "And the colour. Closer."
        case .skin: return "Nearly there. The light here lies; pick what is true."
        case .primary: return "Now the part that matters. When I get stronger, how does it happen?"
        case .secondary: return "And the other half of me. Which one?"
        case .frequency: return "How many days a week do you actually train? Honest number. I plan around it."
        case .motivation: return "Why are we doing this? One answer. I will remember it."
        case .health: return "If your phone already counts your workouts, I can read them. Nothing gets logged twice."
        case .feedback: return "That is who I am, then. Here is what today does to me if we do it."
        }
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        let options = state.bundle.avatarOptions
        switch step {
        case .awaken:
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
        case .hair:
            ChoiceRows(options: options.hairStyles(for: draft.baseBody.rawValue).map { ($0, options.displayName($0)) }, selection: $draft.hairStyleID)
        case .hairColor:
            ChoiceRows(options: options.hairPalettes.map { ($0, options.displayName($0)) }, selection: $draft.hairPaletteID)
        case .skin:
            ChoiceRows(options: options.skinPalettes.map { ($0, options.displayName($0)) }, selection: $draft.skinPaletteID)
        case .primary:
            ChoiceRows(options: state.bundle.families.filter { !["learning", "mindfulness"].contains($0.id.rawValue) }.map { ($0.id.rawValue, $0.displayName) },
                       selection: Binding(get: { prefs.primaryFamily.rawValue }, set: { prefs.primaryFamily = FamilyID($0) }))
        case .secondary:
            ChoiceRows(options: [("learning", "Learning · books, study, skills"), ("mindfulness", "Mindfulness · breath, stillness, daylight")], selection: $prefs.secondaryInterest)
        case .frequency:
            ChoiceRows(options: [(2, "2 days"), (3, "3 days"), (4, "4 days"), (5, "5 days"), (6, "6 days")].map { (String($0.0), $0.1) },
                       selection: Binding(get: { String(prefs.trainingDaysPerWeek) }, set: { prefs.trainingDaysPerWeek = Int($0) ?? 4 }))
        case .motivation:
            ChoiceRows(options: [("strength_goal", "Get stronger"), ("energy", "Have more energy"), ("calm", "A calmer head"), ("discipline", "Keep my word to myself")],
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

    /// Preview of the first day's goals as attribute deltas, with the same +n badge Home uses.
    private var feedback: some View {
        let plan = GoalGenerator.plan(.init(day: DayKey(Date(), calendar: .current), templates: state.bundle.goalTemplates, preferences: prefs, level: 1,
                                            history: [], completions: [], seed: 1, calendar: .current), now: Date())
        var deltas: [AttributeID: Int] = [:]
        for goal in plan.goals {
            guard let t = state.bundle.goalTemplate(goal.templateID), let xp = state.ruleset.goalXP?[goal.slot.rawValue] else { continue }
            deltas[t.attributeID, default: 0] += Int((Double(xp) * state.ruleset.attributePointsPerXP).rounded(.down))
        }
        return VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack {
                ForEach(state.bundle.attributes, id: \.id) { attribute in
                    VStack(spacing: 2) {
                        Text("0").font(HeroFont.statSM).foregroundStyle(NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        Text(attribute.displayName).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    .overlay(alignment: .top) {
                        DeltaBadge(delta: deltas[attribute.id] ?? 0, token: 1, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue)).offset(y: -16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, NeoTokyo.Spacing.md)
            Text("Today's goals, if done, nudge these. Training moves them far more.")
                .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
        }
        .card()
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            if step != .awaken {
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
        case .awaken: return "I think so"
        case .health: return healthAsked || !state.healthAvailable ? "Next" : "Not now"
        case .feedback: return "Wake them up"
        default: return "Next"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next; return }
        guard let ev = state.bundle.evolution(forLevel: 1), let backdrop = state.bundle.defaultBackdrop else { return }
        var r = draft
        r.name = name.trimmingCharacters(in: .whitespaces); r.evolutionID = ev.id; r.backdropID = backdrop.id
        state.completeOnboarding(recipe: r, preferences: prefs)
    }
}

/// One line from the character, left-aligned, no bubble chrome (doc 19: no decorative borders).
struct SpeechLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Large tappable rows, one selected (Finch reference 02, doc 23).
struct ChoiceRows: View {
    let options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            ForEach(options, id: \.0) { id, label in
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
