import SwiftUI
import HeroDomain

/// Doc 01 "daily activity timeline". Facts only; XP shown per event comes from the ledger.
struct HistoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(Date, [ActivityEvent])] {
        // Steps facts are deltas (owner 2026-10-17); the timeline shows them as one row a day, so they are kept out here.
        let byDay = Dictionary(grouping: state.visibleEvents.filter { $0.steps == nil }) { Calendar.current.startOfDay(for: $0.startedAt) }
        let stepDays = Set(state.visibleEvents.filter { $0.steps != nil }.map { Calendar.current.startOfDay(for: $0.startedAt) })
        let days = Set(byDay.keys).union(stepDays)
        return days.sorted(by: >).map { ($0, (byDay[$0] ?? []).sorted { $0.startedAt > $1.startedAt }) }
    }
    /// The day's steps and what they earned, summed over its facts.
    private func stepsRow(_ day: Date) -> (steps: Int, xp: Int)? {
        let facts = state.visibleEvents.filter { $0.steps != nil && Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
        guard !facts.isEmpty else { return nil }
        return (facts.reduce(0) { $0 + ($1.steps ?? 0) }, facts.reduce(0) { $0 + xp(for: $1) })
    }

    private func subtitle(_ event: ActivityEvent) -> String {
        let time = event.startedAt.formatted(date: .omitted, time: .shortened)
        guard let w = state.workout(for: event.id) else {
            var parts = [time]
            if let s = event.structuredSetCount { parts.append("\(s) sets") }
            if let d = event.distanceMeters { parts.append(String(format: "%.1f km", Double(d) / 1000)) }
            if let r = event.rounds { parts.append("\(r) rounds") }
            return parts.joined(separator: " · ")
        }
        let prs = w.personalRecords.filter { !$0.isBaseline }.count
        return "\(time) · \(w.exercises.count) exercises · \(w.validSetCount) sets" + (prs > 0 ? " · \(prs) PR" : "")
    }

    private func stepsRowView(_ s: (steps: Int, xp: Int)) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text("Steps").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                    ImportBadge(disposition: .imported)
                }
                Text("Apple Health").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
            }
            Spacer()
            Text(s.steps.formatted()).font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary)
            Text("+\(s.xp)").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Hierarchy.primary)
        }
        .listRowBackground(NeoTokyo.Surface.raised)
    }

    private func eventRow(_ event: ActivityEvent) -> some View {
        let amount = event.goal != nil ? "goal" : (event.bond != nil ? "bond" : (event.challenge.map { $0.won ? "won" : "lost" } ?? "\(event.durationSeconds / 60) min"))
        return HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(state.displayName(for: event)).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                    ImportBadge(disposition: state.importDisposition(for: event))
                }
                Text(subtitle(event)).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
            }
            Spacer()
            Text(amount).font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary)
            Text("+\(xp(for: event))").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Hierarchy.primary)
        }
        .listRowBackground(NeoTokyo.Surface.raised)
    }

    private func xp(for event: ActivityEvent) -> Int {
        state.ledger.xp.filter { $0.activityEventID == event.id }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if state.visibleEvents.isEmpty {
                    Text("No activity yet.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted).listRowBackground(Color.clear)
                }
                ForEach(grouped, id: \.0) { day, events in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        if let s = stepsRow(day) { stepsRowView(s) }
                        ForEach(events, id: \.id) { event in eventRow(event) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NeoTokyo.Surface.base)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
