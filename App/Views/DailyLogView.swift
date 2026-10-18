import PhaseCore
import SwiftUI

struct DailyLogView: View {
  @Environment(AppStore.self) private var store
  @AppStorage("v2.daily.mode") private var mode = "week"
  @State private var selectedDate = Date()
  @State private var sheet: EditorRoute?
  private let calendar = Calendar.current
  private var week: DateInterval {
    calendar.dateInterval(of: .weekOfYear, for: selectedDate)!
  }
  private var weekDays: [Date] {
    (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
  }
  private var doneDays: Set<Date> { store.state.doneDays(calendar: calendar) }
  private var monthCells: [Date?] {
    let start = calendar.dateInterval(of: .month, for: selectedDate)!.start
    let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
    let count = calendar.range(of: .day, in: .month, for: start)!.count
    return Array(repeating: nil, count: leading)
      + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start) }
  }
  private var weekdayNames: [String] {
    let names = calendar.veryShortStandaloneWeekdaySymbols
    return (0..<7).map { names[($0 + calendar.firstWeekday - 1) % 7] }
  }
  private func records(_ day: Date) -> [Entry] {
    store.state.recordTimeline().filter { calendar.isDate($0.date, inSameDayAs: day) }
  }
  var body: some View {
    ScrollViewReader { proxy in
      List {
        Section {
          Picker("Calendar", selection: $mode) {
            Text("Week").tag("week"); Text("Month").tag("month")
          }.pickerStyle(.segmented)
          HStack {
            Button("Previous", systemImage: "chevron.left") { shift(-1) }.labelStyle(.iconOnly).help("Previous \(mode)")
            Spacer()
            Text(mode == "month"
                 ? selectedDate.formatted(.dateTime.year().month(.wide))
                 : "\(week.start.formatted(.dateTime.month(.abbreviated).day())) – \(weekDays.last!.formatted(.dateTime.month(.abbreviated).day().year()))")
              .font(.subheadline)
            Spacer()
            Button("Next", systemImage: "chevron.right") { shift(1) }.labelStyle(.iconOnly).help("Next \(mode)")
          }.buttonStyle(.borderless)
          if mode == "month" {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
              ForEach(weekdayNames.indices, id: \.self) { Text(weekdayNames[$0]).font(.caption).foregroundStyle(.secondary) }
              ForEach(monthCells.indices, id: \.self) { index in
                if let day = monthCells[index] { dayButton(day, showWeekday: false) }
                else { Color.clear.frame(height: 42).accessibilityHidden(true) }
              }
            }
          } else {
            HStack(spacing: 2) {
              ForEach(weekDays, id: \.self) { day in dayButton(day, showWeekday: true) }
            }
          }
        }
        if mode == "week" {
          let summary = store.state.performedAreaDays(in: week, calendar: calendar)
          if !summary.isEmpty {
            Section {
              ForEach(summary) { item in Text("\(item.title) · \(item.days) days").font(.caption).foregroundStyle(.secondary) }
            } header: { Text("Performed days by Area").font(.caption) }
          }
          // The week remains visible in full. Selecting a day scrolls, never filters the week.
          ForEach(weekDays, id: \.self) { day in
            let dayRecords = records(day)
            if !dayRecords.isEmpty || calendar.isDate(day, inSameDayAs: selectedDate) {
              Section(day.formatted(date: .complete, time: .omitted)) {
                ForEach(dayRecords) { RecordRow(entry: $0) }
                if dayRecords.isEmpty { Text("No records").foregroundStyle(.secondary) }
              }.id(calendar.startOfDay(for: day))
            }
          }
        } else {
          Section(selectedDate.formatted(date: .complete, time: .omitted)) {
            let dayRecords = records(selectedDate)
            ForEach(dayRecords) { RecordRow(entry: $0) }
            if dayRecords.isEmpty { Text("No records").foregroundStyle(.secondary) }
          }
        }
      }
      .onChange(of: selectedDate) { _, day in
        if mode == "week" { withAnimation { proxy.scrollTo(calendar.startOfDay(for: day), anchor: .top) } }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Record Done", systemImage: "checkmark.circle") { sheet = .done(nil) }
          .labelStyle(.iconOnly).help("Record Done without a task")
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
  }
  private func shift(_ direction: Int) {
    if let next = calendar.date(byAdding: mode == "month" ? .month : .weekOfYear, value: direction, to: selectedDate) {
      selectedDate = next
    }
  }
  private func dayButton(_ day: Date, showWeekday: Bool) -> some View {
    let selected = calendar.isDate(day, inSameDayAs: selectedDate)
    let performed = doneDays.contains(calendar.startOfDay(for: day))
    return Button { selectedDate = day } label: {
      VStack(spacing: 3) {
        if showWeekday { Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2) }
        Text(day.formatted(.dateTime.day())).font(.subheadline)
        Circle().fill(performed ? Color.accentColor : Color.clear).frame(width: 4, height: 4)
      }.frame(maxWidth: .infinity, minHeight: 42)
        .background(selected ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    .accessibilityValue(performed ? "Performed" : "No performed record")
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }
}
