import PhaseCore
import SwiftUI

struct DailyLogView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedDay: Date?
  @State private var datesExpanded = false
  @State private var sheet: EditorRoute?
  private let calendar = Calendar.current
  private var days: [Date] { store.state.dailyDays(calendar: calendar) }
  private var effectiveDay: Date? {
    if let selectedDay, days.contains(selectedDay) { return selectedDay }
    return days.first
  }
  private var doneDays: [Date] { store.state.doneDays(calendar: calendar).sorted(by: >) }
  private var records: [Entry] {
    guard let day = effectiveDay else { return [] }
    return store.state.entries.filter {
      ($0.kind == .done || $0.kind == .event) && calendar.isDate($0.date, inSameDayAs: day)
    }.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
  }
  var body: some View {
    List {
      Section("Performed days") {
        Text("One mark per day with a Done record. Lifecycle events do not contribute.").font(
          .caption
        ).foregroundStyle(.secondary)
        if doneDays.isEmpty { Text("No performed days yet.").foregroundStyle(.secondary) }
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 60, maximum: 90))], alignment: .leading, spacing: 12
        ) {
          ForEach(doneDays, id: \.self) { day in
            Button {
              selectedDay = day
            } label: {
              VStack(spacing: 5) {
                Image(systemName: effectiveDay == day ? "square.inset.filled" : "square.fill")
                Text(day.formatted(.dateTime.month(.abbreviated).day())).font(.caption2)
                Text(day.formatted(.dateTime.year())).font(.caption2).foregroundStyle(.secondary)
              }.frame(maxWidth: .infinity).padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Performed day \(day.formatted(date: .complete, time: .omitted))")
            .accessibilityAddTraits(effectiveDay == day ? [.isSelected] : [])
          }
        }
      }
      Section("Dates with records") {
        if days.isEmpty {
          Text("No records yet. Record something you performed to begin.").foregroundStyle(
            .secondary)
        }
        DisclosureGroup("All dates (\(days.count))", isExpanded: $datesExpanded) {
          ForEach(days, id: \.self) { day in
            Button {
              selectedDay = day
            } label: {
              HStack {
                Text(day.formatted(date: .complete, time: .omitted))
                Spacer()
                if effectiveDay == day {
                  Image(systemName: "checkmark").accessibilityLabel("Selected")
                }
              }
            }.buttonStyle(.plain)
          }
        }
      }
      if let day = effectiveDay {
        Section(day.formatted(date: .complete, time: .omitted)) {
          ForEach(records) { entry in RecordRow(entry: entry) }
        }
      }
      Section {
        Button("Record Done without a task", systemImage: "checkmark") { sheet = .done(nil) }
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
  }
}
