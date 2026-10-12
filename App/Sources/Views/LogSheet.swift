import SwiftUI
import HeroDomain
import HeroContent

/// Doc 02 "manual activity": pick, set a duration, done. Owner 2026-10-12: one entry point for everything. The
/// list is tabbed by the attribute each family feeds, using the stat glyphs; the Strength tab also offers the
/// live workout tracker (sets, weights, PRs) as an optional way in. Two modes so the duration step is the only
/// thing on screen once an activity is chosen (owner, 2026-09-30).
struct LogSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// Hands off to the live strength tracker (the sheet closes, Home opens the tracker).
    var onTrackWorkout: (() -> Void)? = nil
    @State private var query = ""
    @State private var tab: AttributeID?
    @State private var selected: ContentBundle.ActivityType?
    @State private var minutes = 30
    @State private var sets = 0
    @State private var distanceHalfKm = 0   // distance in 0.5 km steps
    @State private var rounds = 0

    private var recentIDs: [ActivityTypeID] {
        var seen: [ActivityTypeID] = []
        for e in state.events.sorted(by: { $0.startedAt > $1.startedAt }) where !seen.contains(e.activityTypeID) { seen.append(e.activityTypeID) }
        return Array(seen.prefix(4))
    }

    /// The attribute a family feeds most, which is the tab its activities live under.
    private func attribute(for family: FamilyID) -> AttributeID {
        BondReference.attribute(forFamily: family.rawValue, ruleset: state.ruleset, fallback: state.bundle.attributes.first?.id ?? "strength")
    }
    private var currentTab: AttributeID { tab ?? attribute(for: state.goalPreferences.primaryFamily) }

    private var listed: [ContentBundle.ActivityType] {
        let all = state.bundle.activityTypes
        if !query.isEmpty { return all.filter { $0.displayName.localizedCaseInsensitiveContains(query) } }
        let inTab = all.filter { attribute(for: $0.familyID) == currentTab }
        let recent = recentIDs.compactMap { state.bundle.activityType($0) }.filter { attribute(for: $0.familyID) == currentTab }
        return recent + inTab.filter { a in !recentIDs.contains(a.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selected { duration(for: selected) } else { picker }
            }
            .background(NeoTokyo.Surface.base)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if selected != nil {
                    ToolbarItem(placement: .topBarTrailing) { Button("Change") { selected = nil } }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var picker: some View {
        VStack(spacing: 0) {
            if query.isEmpty { tabs }
            List {
                if query.isEmpty, currentTab == "strength", let onTrackWorkout {
                    Section {
                        Button {
                            onTrackWorkout()
                        } label: {
                            HStack(spacing: NeoTokyo.Spacing.md) {
                                Image(systemName: "dumbbell.fill").font(HeroFont.headline).foregroundStyle(NeoTokyo.Attribute.color(for: "strength"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(state.activeWorkout == nil ? "Track a workout live" : "Resume your workout").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                                    Text("Sets, weights and personal records. Optional.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                            }
                        }
                        .listRowBackground(NeoTokyo.Surface.raised)
                    }
                }
                Section(query.isEmpty ? "Activities" : "Results") {
                    ForEach(listed, id: \.id) { activity in
                        Button {
                            minutes = max(5, (activity.defaultDurationSeconds ?? 1800) / 60)
                            sets = 0; distanceHalfKm = 0; rounds = 0
                            selected = activity
                        } label: {
                            HStack {
                                Text(activity.displayName).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                                Spacer()
                                Text(state.bundle.family(activity.familyID)?.displayName ?? "").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                            }
                        }
                    }
                    .listRowBackground(NeoTokyo.Surface.raised)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .searchable(text: $query, prompt: "Search activities")
    }

    /// One tab per attribute, each with its glyph: the icon is the label, the word stays small under it.
    private var tabs: some View {
        HStack(spacing: NeoTokyo.Spacing.xs) {
            ForEach(state.bundle.attributes, id: \.id) { attribute in
                let on = currentTab == attribute.id
                let color = NeoTokyo.Attribute.color(for: attribute.id.rawValue)
                Button { withAnimation(.snappy) { tab = attribute.id } } label: {
                    VStack(spacing: 3) {
                        Image(systemName: AttributeGlyph.symbol(for: attribute.id)).font(HeroFont.headline)
                        Text(attribute.displayName).font(HeroFont.label)
                    }
                    .foregroundStyle(on ? color : NeoTokyo.Text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NeoTokyo.Spacing.sm)
                    .background(on ? NeoTokyo.Surface.overlay : .clear, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.vertical, NeoTokyo.Spacing.sm)
    }

    private func duration(for activity: ContentBundle.ActivityType) -> some View {
        VStack(spacing: NeoTokyo.Spacing.xl) {
            Spacer(minLength: NeoTokyo.Spacing.xl)
            VStack(spacing: NeoTokyo.Spacing.lg) {
                Text(activity.displayName).font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                HStack(spacing: 6) {
                    let attr = attribute(for: activity.familyID)
                    Image(systemName: AttributeGlyph.symbol(for: attr)).font(HeroFont.caption)
                    Text(state.bundle.family(activity.familyID)?.displayName ?? "").font(HeroFont.caption)
                }
                .foregroundStyle(NeoTokyo.Text.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(minutes, format: .number).font(HeroFont.statXL).foregroundStyle(NeoTokyo.Text.primary)
                        .contentTransition(.numericText(value: Double(minutes)))
                    Text("min").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.secondary)
                }
                .padding(.top, NeoTokyo.Spacing.md)
                HStack(spacing: NeoTokyo.Spacing.lg) {
                    stepButton("minus") { withAnimation(.snappy) { minutes = max(5, minutes - 5) } }
                    stepButton("plus") { withAnimation(.snappy) { minutes = min(240, minutes + 5) } }
                }
                extras(for: activity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.xxl)
            .card()
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            Spacer()
            Button("Done") {
                state.log(activityTypeID: activity.id, minutes: minutes, sets: sets, distanceMeters: distanceHalfKm * 500, rounds: rounds)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.bottom, NeoTokyo.Spacing.lg)
        }
    }

    /// Owner QA 2026-10-02: optional facts by family. Sets for strength (they count for the set-based credit
    /// floor), distance for cardio, rounds for combat. All optional, all facts.
    @ViewBuilder
    private func extras(for activity: ContentBundle.ActivityType) -> some View {
        // Which extras an activity offers is content (`logging_extras`), never a family switch here (rule 6).
        if activity.offers("sets") {
            extraRow(label: "Sets", value: sets == 0 ? "—" : "\(sets)", hint: "optional") { sets = max(0, sets - 1) } plus: { sets = min(60, sets + 1) }
        }
        if activity.offers("distance") {
            extraRow(label: "Distance", value: distanceHalfKm == 0 ? "—" : String(format: "%.1f km", Double(distanceHalfKm) / 2), hint: "optional") { distanceHalfKm = max(0, distanceHalfKm - 1) } plus: { distanceHalfKm = min(200, distanceHalfKm + 1) }
        }
        if activity.offers("rounds") {
            extraRow(label: "Rounds", value: rounds == 0 ? "—" : "\(rounds)", hint: "optional") { rounds = max(0, rounds - 1) } plus: { rounds = min(40, rounds + 1) }
        }
    }

    private func extraRow(label: String, value: String, hint: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: NeoTokyo.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                Text(hint).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.muted)
            }
            Spacer()
            Button { withAnimation(.snappy) { minus() } } label: { Image(systemName: "minus").frame(width: 40, height: 36) }.buttonStyle(SecondaryButtonStyle()).frame(width: 52)
            Text(value).font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.primary).frame(minWidth: 64)
            Button { withAnimation(.snappy) { plus() } } label: { Image(systemName: "plus").frame(width: 40, height: 36) }.buttonStyle(SecondaryButtonStyle()).frame(width: 52)
        }
        .padding(.top, NeoTokyo.Spacing.md)
        .padding(.horizontal, NeoTokyo.Spacing.lg)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                .frame(width: 72, height: 56)
        }
        .buttonStyle(SecondaryButtonStyle())
        .frame(width: 96)
    }
}
