import SwiftUI
import HeroDomain
import HeroContent

/// Doc 02 "Strength workout": exercises with previous performance, editable sets, finish.
/// Fitness first: this screen is pure utility; the reward moment happens on Home afterwards.
struct WorkoutView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showAddExercise = false
    @State private var confirmDiscard = false
    @State private var askLength = false
    @State private var sessionMinutes: Double? = 45

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NeoTokyo.Spacing.lg) {
                    if let w = state.activeWorkout {
                        summary(w)
                        ForEach(w.exercises) { exercise in
                            ExerciseCard(exercise: exercise)
                        }
                        Button("Add exercise") { showAddExercise = true }.buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.bottom, 96)
            }
            .background(NeoTokyo.Surface.base)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { confirmDiscard = true }.foregroundStyle(NeoTokyo.Hierarchy.destructive) }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Unit", selection: Binding(get: { state.preferredUnit }, set: { state.preferredUnit = $0 })) {
                        ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Finish workout") {
                    sessionMinutes = Double(state.suggestedWorkoutMinutes())
                    askLength = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((state.activeWorkout?.validSetCount ?? 0) == 0)
                .padding(.horizontal, NeoTokyo.Spacing.lg).padding(.bottom, NeoTokyo.Spacing.sm)
                .background(NeoTokyo.Surface.base.opacity(0.92))
            }
            .sheet(isPresented: $showAddExercise) { AddExerciseSheet() }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { state.discardWorkout(); dismiss() }
            }
            .alert("How long was this session?", isPresented: $askLength) {
                TextField("Minutes", value: $sessionMinutes, format: .number).keyboardType(.numberPad)
                Button("Finish") { if state.finishWorkout(sessionMinutes: sessionMinutes.map { Int($0) }) { dismiss() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sessions logged after the fact default to \(Int(state.ruleset.structuredWorkout?.defaultMinutes ?? 45)) minutes. Credit is at least \(state.ruleset.structuredWorkout.map { String(format: "%.1f", $0.minutesPerValidSet) } ?? "2.5") minutes per completed set.")
            }
            .onAppear { if state.activeWorkout == nil { state.startWorkout() } }
        }
        .interactiveDismissDisabled()
    }

    private func summary(_ w: Workout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.xl) {
            StatNumber(value: w.validSetCount, unit: w.validSetCount == 1 ? "set" : "sets")
            StatNumber(value: Int(state.preferredUnit.fromKilograms(w.totalVolumeKg).rounded()), unit: state.preferredUnit.rawValue)
            Spacer()
            Text(w.startedAt.formatted(date: .omitted, time: .shortened)).font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct ExerciseCard: View {
    @Environment(AppState.self) private var state
    let exercise: WorkoutExercise

    var body: some View {
        let previous = state.previousSets(for: exercise.exerciseID)
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
            HStack {
                Text(state.bundle.exercise(exercise.exerciseID)?.displayName ?? exercise.exerciseID.rawValue).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                Button { state.removeExercise(exercise.id) } label: { Image(systemName: "xmark").font(HeroFont.caption) }.foregroundStyle(NeoTokyo.Text.muted)
            }
            HStack {
                Text("Set").frame(width: 32, alignment: .leading)
                Text("Previous").frame(width: 92, alignment: .leading)
                Spacer()
                Text(columnTitles(exercise.sets.first?.type ?? .weighted)).frame(width: 150, alignment: .trailing)
                Text("").frame(width: 28)
            }
            .font(HeroFont.label).textCase(.uppercase).tracking(0.8).foregroundStyle(NeoTokyo.Text.secondary)
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRow(index: index + 1, set: set, previous: index < previous.count ? previous[index] : nil, unit: state.preferredUnit,
                       onChange: { state.updateSet($0, in: exercise.id) }, onDelete: { state.removeSet(set.id, in: exercise.id) })
            }
            Button("Add set") { state.addSet(to: exercise.id) }.font(HeroFont.callout).foregroundStyle(NeoTokyo.Hierarchy.fallback)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func columnTitles(_ type: SetType) -> String {
        switch type { case .weighted: return "Weight · Reps"; case .bodyweight, .assisted: return "Reps"; case .timed: return "Seconds" }
    }
}

struct SetRow: View {
    let index: Int
    let set: WorkoutSet
    let previous: WorkoutSet?
    let unit: WeightUnit
    let onChange: (WorkoutSet) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            Text(index, format: .number).font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary).frame(width: 32, alignment: .leading)
            Text(previousLabel).font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.muted).frame(width: 92, alignment: .leading)
            Spacer()
            switch set.type {
            case .weighted:
                NumberField(value: weightBinding, placeholder: unit.rawValue, width: 72)
                Text("×").foregroundStyle(NeoTokyo.Text.muted)
                NumberField(value: intBinding(\.reps), placeholder: "reps", width: 56)
            case .bodyweight, .assisted:
                NumberField(value: intBinding(\.reps), placeholder: "reps", width: 72)
            case .timed:
                NumberField(value: intBinding(\.durationSeconds), placeholder: "sec", width: 72)
            }
            Button { var s = set; s.completed.toggle(); onChange(s) } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(set.completed ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.muted)
            }
            .frame(width: 28)
        }
        .contextMenu { Button("Delete set", role: .destructive, action: onDelete) }
    }

    private var previousLabel: String {
        guard let p = previous else { return "—" }
        switch p.type {
        case .weighted: return "\(fmt(unit.fromKilograms(p.weightKg ?? 0))) × \(p.reps ?? 0)"
        case .bodyweight, .assisted: return "\(p.reps ?? 0) reps"
        case .timed: return "\(p.durationSeconds ?? 0) s"
        }
    }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    private var weightBinding: Binding<Double?> {
        Binding(get: { set.weightKg.map { unit.fromKilograms($0) } },
                set: { var s = set; s.weightKg = $0.map { unit.toKilograms($0) }; s.enteredUnit = unit; onChange(s) })
    }
    private func intBinding(_ key: WritableKeyPath<WorkoutSet, Int?>) -> Binding<Double?> {
        Binding(get: { set[keyPath: key].map(Double.init) }, set: { var s = set; s[keyPath: key] = $0.map { Int($0) }; onChange(s) })
    }
}

/// Numeric entry with tabular digits; empty when nil.
struct NumberField: View {
    @Binding var value: Double?
    let placeholder: String
    let width: CGFloat
    var body: some View {
        TextField(placeholder, value: $value, format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(HeroFont.bodyNumber)
            .foregroundStyle(NeoTokyo.Text.primary)
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.sm))
            .frame(width: width)
    }
}

struct AddExerciseSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var listed: [ContentBundle.ExerciseDefinition] {
        let all = state.bundle.exerciseDefinitions
        if !query.isEmpty { return all.filter { $0.displayName.localizedCaseInsensitiveContains(query) } }
        // recent first: exercises from the latest finished workouts
        var recent: [ExerciseID] = []
        for w in state.workouts.sorted(by: { $0.startedAt > $1.startedAt }) { for e in w.exercises where !recent.contains(e.exerciseID) { recent.append(e.exerciseID) } }
        let recentDefs = recent.compactMap { state.bundle.exercise($0) }
        return recentDefs + all.filter { d in !recent.contains(d.id) }
    }

    var body: some View {
        NavigationStack {
            List(listed, id: \.id) { def in
                Button {
                    state.addExercise(def.id); dismiss()
                } label: {
                    HStack {
                        Text(def.displayName).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                        Spacer()
                        Text(def.muscleGroup.capitalized).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    }
                }
                .listRowBackground(NeoTokyo.Surface.raised)
            }
            .scrollContentBackground(.hidden)
            .background(NeoTokyo.Surface.base)
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
