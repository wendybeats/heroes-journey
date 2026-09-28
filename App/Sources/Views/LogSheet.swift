import SwiftUI
import HeroDomain
import HeroContent

/// Doc 02 "manual activity": recent first, search, duration, done. Target under 10 s.
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
            List {
                if let selected {
                    Section {
                        Stepper(value: $minutes, in: 5...240, step: 5) {
                            HStack { Text(selected.displayName).font(HeroFont.bodyMedium); Spacer(); Text("\(minutes) min").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary) }
                        }
                        Button("Done") {
                            state.log(activityTypeID: selected.id, minutes: minutes)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .listRowBackground(Color.clear)
                    }
                    .listRowBackground(NeoTokyo.Surface.raised)
                }
                Section(query.isEmpty ? "Recent and all" : "Results") {
                    ForEach(listed, id: \.id) { activity in
                        Button {
                            selected = activity
                            minutes = max(5, (activity.defaultDurationSeconds ?? 1800) / 60)
                        } label: {
                            HStack {
                                Text(activity.displayName).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                                Spacer()
                                Text(state.bundle.family(activity.familyID)?.displayName ?? "")
                                    .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                                if selected?.id == activity.id { Image(systemName: "checkmark").foregroundStyle(NeoTokyo.Hierarchy.primary) }
                            }
                        }
                    }
                    .listRowBackground(NeoTokyo.Surface.raised)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NeoTokyo.Surface.base)
            .searchable(text: $query, prompt: "Search activities")
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
