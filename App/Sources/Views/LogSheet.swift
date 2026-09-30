import SwiftUI
import HeroDomain
import HeroContent

/// Doc 02 "manual activity": pick, set a duration, done. Two modes so the duration step is the
/// only thing on screen once an activity is chosen (owner, 2026-09-30).
struct LogSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: ContentBundle.ActivityType?
    @State private var minutes = 30

    private var recentIDs: [ActivityTypeID] {
        var seen: [ActivityTypeID] = []
        for e in state.events.sorted(by: { $0.startedAt > $1.startedAt }) where !seen.contains(e.activityTypeID) { seen.append(e.activityTypeID) }
        return Array(seen.prefix(4))
    }

    private var listed: [ContentBundle.ActivityType] {
        let all = state.bundle.activityTypes
        if !query.isEmpty { return all.filter { $0.displayName.localizedCaseInsensitiveContains(query) } }
        let recent = recentIDs.compactMap { state.bundle.activityType($0) }
        return recent + all.filter { a in !recentIDs.contains(a.id) }
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
        List {
            Section(query.isEmpty ? "Recent and all" : "Results") {
                ForEach(listed, id: \.id) { activity in
                    Button {
                        minutes = max(5, (activity.defaultDurationSeconds ?? 1800) / 60)
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
        .searchable(text: $query, prompt: "Search activities")
    }

    private func duration(for activity: ContentBundle.ActivityType) -> some View {
        VStack(spacing: NeoTokyo.Spacing.xl) {
            Spacer(minLength: NeoTokyo.Spacing.xl)
            VStack(spacing: NeoTokyo.Spacing.lg) {
                Text(activity.displayName).font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                Text(state.bundle.family(activity.familyID)?.displayName ?? "").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NeoTokyo.Spacing.xxl)
            .card()
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            Spacer()
            Button("Done") {
                state.log(activityTypeID: activity.id, minutes: minutes)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.bottom, NeoTokyo.Spacing.lg)
        }
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
