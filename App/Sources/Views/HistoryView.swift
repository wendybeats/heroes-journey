import SwiftUI
import HeroDomain

/// Doc 01 "daily activity timeline". Facts only; XP shown per event comes from the ledger.
struct HistoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(Date, [ActivityEvent])] {
        let byDay = Dictionary(grouping: state.visibleEvents) { Calendar.current.startOfDay(for: $0.startedAt) }
        return byDay.keys.sorted(by: >).map { ($0, byDay[$0]!.sorted { $0.startedAt > $1.startedAt }) }
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
                        ForEach(events, id: \.id) { event in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        Text(state.displayName(for: event))
                                            .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                                        ImportBadge(disposition: state.importDisposition(for: event))
                                    }
                                    Text(subtitle(event))
                                        .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                                }
                                Spacer()
                                Text(event.goal != nil ? "goal" : "\(event.durationSeconds / 60) min").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary)
                                Text("+\(xp(for: event))").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Hierarchy.primary)
                            }
                        }
                        .listRowBackground(NeoTokyo.Surface.raised)
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
