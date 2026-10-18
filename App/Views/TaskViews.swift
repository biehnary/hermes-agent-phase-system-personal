import Foundation
import PhaseCore
import SwiftUI

struct TasksView: View {
  @Environment(AppStore.self) private var store
  @AppStorage("v2.task.kind") private var kind = "all"
  @AppStorage("v2.task.areas") private var areaSelection = ""
  @AppStorage("v2.task.sort") private var sort = "grouped"
  @State private var filtersVisible = false
  @State private var sheet: EditorRoute?
  private var selectedAreas: Set<String> { Set(areaSelection.split(separator: "|").map(String.init)) }
  private var filtered: Bool { kind != "all" || !selectedAreas.isEmpty || sort != "grouped" }
  private var tasks: [Entry] {
    store.state.currentTasks().filter { task in
      (kind == "all" || task.taskKind == kind)
        && (selectedAreas.isEmpty || selectedAreas.contains(areaKey(task)))
    }.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return sort == "oldest" ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }
  private func areaKey(_ task: Entry) -> String {
    task.phaseID.flatMap { store.state.entry($0)?.areaID }?.uuidString ?? task.areaID?.uuidString ?? "unassigned"
  }
  private func groupTitle(_ task: Entry) -> String {
    let phase = task.phaseID.flatMap { store.state.entry($0) }
    let area = (phase?.areaID ?? task.areaID).flatMap { store.state.entry($0) }
    return "\(area?.title ?? "Unassigned") / \(phase?.title ?? "Unassigned")"
  }
  // Identity is the placement, not the display name (duplicate phase names are allowed).
  private var groups: [[Entry]] {
    let grouped = Dictionary(grouping: tasks) { $0.phaseID?.uuidString ?? areaKey($0) }
    return grouped.values.sorted {
      let a = groupTitle($0[0]), b = groupTitle($1[0])
      return a == b ? $0[0].id.uuidString < $1[0].id.uuidString : a.localizedStandardCompare(b) == .orderedAscending
    }
  }
  var body: some View {
    List {
      Section {
        NavigationLink("Ended tasks") { EndedTasksView() }
      }
      if filtersVisible {
        Section("Filters & sort") {
          Picker("Kind", selection: $kind) {
            Text("All").tag("all"); Text("General").tag("general"); Text("Quick").tag("quick")
          }
          Picker("Sort", selection: $sort) {
            Text("Area / Phase").tag("grouped")
            Text("Created newest first").tag("newest")
            Text("Created oldest first").tag("oldest")
          }
          ForEach(store.state.items(.area).sorted { $0.title < $1.title }) { area in
            areaToggle(area.title, key: area.id.uuidString)
          }
          areaToggle("Unassigned", key: "unassigned")
          Button("Clear all") { kind = "all"; areaSelection = ""; sort = "grouped" }
        }
      }
      if filtered { Text("Filters / sort active").font(.caption).foregroundStyle(.secondary) }
      if tasks.isEmpty { Text("No matching tasks").foregroundStyle(.secondary) }
      if sort == "grouped" {
        ForEach(groups, id: \.first!.id) { group in
          Section(groupTitle(group[0])) {
            ForEach(group) { TaskListRow(entry: $0) }
          }
        }
      } else {
        ForEach(tasks) { TaskListRow(entry: $0) }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Add Task", systemImage: "plus.rectangle") { sheet = .entry(Entry(kind: .task)) }
          .labelStyle(.iconOnly).help("Add Task")
      }
      ToolbarItem(placement: .secondaryAction) {
        Button("Filters", systemImage: filtered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
          filtersVisible.toggle()
        }.labelStyle(.iconOnly).help("Filters & sort")
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
  }
  private func areaToggle(_ title: String, key: String) -> some View {
    Toggle(title, isOn: Binding(get: { selectedAreas.contains(key) }, set: { enabled in
      var values = selectedAreas
      if enabled { values.insert(key) } else { values.remove(key) }
      areaSelection = values.sorted().joined(separator: "|")
    }))
  }
}

struct EndedTasksView: View {
  @Environment(AppStore.self) private var store
  @AppStorage("v2.ended.type") private var type = "all"
  private var tasks: [Entry] {
    store.state.items(.task).filter { $0.lifecycle != "active" && (type == "all" || $0.lifecycle == type) }
      .sorted { lhs, rhs in
        let a = endedDate(lhs), b = endedDate(rhs)
        return a == b ? lhs.id.uuidString < rhs.id.uuidString : a > b
      }
  }
  private func endedDate(_ task: Entry) -> Date {
    store.state.items(.event).filter { $0.taskID == task.id && ["completed", "stopped"].contains($0.text) }
      .map(\.date).max() ?? task.updatedAt
  }
  var body: some View {
    List {
      Picker("Status", selection: $type) {
        Text("All").tag("all"); Text("Completed").tag("completed"); Text("Stopped").tag("stopped")
      }.pickerStyle(.segmented)
      ForEach(tasks) { EntryLink(entry: $0) }
      if tasks.isEmpty { Text("No ended tasks").foregroundStyle(.secondary) }
    }.navigationTitle("Ended tasks")
  }
}

struct TaskListRow: View {
  @Environment(AppStore.self) private var store
  let entry: Entry
  var body: some View {
    HStack {
      EntryLink(entry: entry)
      if entry.lifecycle == "active" {
        Button {
          _ = store.apply { try $0.toggleSpotlight(entry.id) }
        } label: {
          VStack(spacing: 2) {
            Image(systemName: entry.isSpotlight ? "star.fill" : "star")
            Text(entry.isSpotlight ? "ON" : "OFF").font(.caption2)
          }.frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .help(entry.isSpotlight ? "Remove from Spotlight" : "Add to Spotlight")
        .accessibilityLabel(entry.isSpotlight ? "Remove \(entry.title) from Spotlight" : "Add \(entry.title) to Spotlight")
        .accessibilityValue(entry.isSpotlight ? "On" : "Off")
      }
    }.listRowBackground(taskCardColor(entry))
  }
}

func taskCardColor(_ entry: Entry) -> Color {
  entry.taskKind == "quick" ? Color.orange.opacity(0.09) : Color.blue.opacity(0.06)
}

struct ResourceContent: View {
  let text: String
  private var urls: [URL] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
    let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
    var seen = Set<URL>()
    return matches.compactMap { match in
      guard let url = match.url, let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
        let host = url.host, !host.isEmpty, url.user == nil, url.password == nil, seen.insert(url).inserted else { return nil }
      return url
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(text).textSelection(.enabled)
      ForEach(urls, id: \.self) { url in
        Link(destination: url) { Label(url.absoluteString, systemImage: "link") }
      }
    }
  }
}

/// Shared inline pagination: five initially, More adds five, View all never navigates.
struct MoreControls: View {
  let total: Int
  @Binding var limit: Int
  var body: some View {
    if total > 5 {
      HStack {
        if limit >= total {
          Button("Collapse") { limit = 5 }
        } else {
          Button("View all") { limit = total }
          Spacer()
          Button("More") { limit = min(total, limit + 5) }
        }
      }.buttonStyle(.borderless)
    }
  }
}

struct TaskDetailView: View {
  @Environment(AppStore.self) private var store
  let id: UUID
  @State private var sheet: EditorRoute?
  @State private var historyLimit = 5
  @State private var ending: String?
  var body: some View {
    Group {
      if let task = store.state.entry(id) {
        List {
          Section {
            Text("\(task.taskKind.capitalized) · \(task.lifecycle.capitalized)").font(.caption).foregroundStyle(.secondary)
            if let phaseID = task.phaseID, let phase = store.state.entry(phaseID) {
              NavigationLink { ClassificationDetailView(id: phaseID) } label: {
                Label(phaseNavigationTitle(phase), systemImage: "square.stack")
              }
            }
            let resume = store.state.resume(taskID: id)
            if !resume.isEmpty { Text(resume).textSelection(.enabled) }
            if task.lifecycle == "active" {
              Button("Record Done", systemImage: "checkmark.circle.fill") { sheet = .done(id) }
                .accessibilityIdentifier("recordDone")
            }
          }
          if !task.text.isEmpty || !task.notes.isEmpty {
            Section("Description") {
              if !task.text.isEmpty { Text(task.text).textSelection(.enabled) }
              if !task.notes.isEmpty { Text(task.notes).textSelection(.enabled) }
            }
          }
          if !task.resources.isEmpty { Section("Resources") { ResourceContent(text: task.resources) } }
          Section("History") {
            let history = store.state.recordTimeline().filter { $0.taskID == id }
            ForEach(Array(history.prefix(historyLimit))) { entry in RecordRow(entry: entry, showTaskLink: false) }
            if history.isEmpty { Text("No records").foregroundStyle(.secondary) }
            MoreControls(total: history.count, limit: $historyLimit)
          }
        }
        .navigationTitle(task.title)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Edit", systemImage: "pencil") { sheet = .entry(task) }
              if task.lifecycle == "active" {
                Button(task.isSpotlight ? "Remove from Spotlight" : "Add to Spotlight", systemImage: task.isSpotlight ? "star.slash" : "star") {
                  _ = store.apply { try $0.toggleSpotlight(id) }
                }
                Button("Complete", systemImage: "checkmark.circle") { ending = "completed" }
                Button("Stop", systemImage: "stop.circle") { ending = "stopped" }
              } else {
                Button("Reopen", systemImage: "arrow.uturn.backward") { _ = store.apply { try $0.reopenTask(id) } }
              }
            } label: { Label("Task actions", systemImage: "ellipsis.circle") }
          }
        }
      } else { ContentUnavailableView("Task unavailable", systemImage: "questionmark.folder") }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
    .sheet(isPresented: Binding(get: { ending != nil }, set: { if !$0 { ending = nil } })) {
      EndTaskSheet(id: id, status: ending ?? "completed")
    }
  }
  private func phaseNavigationTitle(_ phase: Entry) -> String {
    let area = phase.areaID.flatMap { store.state.entry($0)?.title } ?? "Unassigned"
    return "\(area) / \(phase.title)"
  }
}

struct EndTaskSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(UIPresentationState.self) private var presentations
  @Environment(\.dismiss) private var dismiss
  @State private var presentationID = UUID()
  let id: UUID
  let status: String
  @State private var finalDone = ""
  var body: some View {
    NavigationStack {
      Form {
        Section("Final performed record (optional)") {
          TextField("What did you do?", text: $finalDone, axis: .vertical)
          Text("Blank ends the task without a Done. History is retained. Reopening does not restore Spotlight.").font(.caption).foregroundStyle(.secondary)
        }
      }.navigationTitle(status == "completed" ? "Complete task" : "Stop task")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Confirm") {
              if store.apply({ try $0.endTask(id, status: status, finalDone: finalDone) }) { dismiss() }
            }
          }
        }
    }
    .storeErrorAlert(enabled: presentations.sheets.last == presentationID)
    .onAppear { if !presentations.sheets.contains(presentationID) { presentations.sheets.append(presentationID) } }
    .onDisappear { presentations.sheets.removeAll { $0 == presentationID } }
  }
}

struct RecordRow: View {
  @Environment(AppStore.self) private var store
  let entry: Entry
  var showTaskLink = true
  @State private var sheet: EditorRoute?
  @State private var deleting = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if entry.kind == .event {
        Text("Task \(entry.text)").font(.caption).foregroundStyle(.secondary)
        Text(entry.title)
      } else {
        if showTaskLink && !entry.title.isEmpty { Text(entry.title).font(.caption).foregroundStyle(.secondary) }
        if let status = store.state.lifecycleLabel(for: entry) {
          Text("Task \(status)").font(.caption).foregroundStyle(.secondary)
        }
        Text(entry.text).textSelection(.enabled)
        if !entry.notes.isEmpty { Text(entry.notes).foregroundStyle(.secondary).textSelection(.enabled) }
      }
      Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
    }.padding(.vertical, 6)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        if entry.kind == .done {
          Button("Delete record", systemImage: "trash", role: .destructive) { deleting = true }.tint(.red)
          Button("Edit record", systemImage: "pencil") { sheet = .editDone(entry) }.tint(.blue)
        }
      }
      .contextMenu {
        if entry.kind == .done {
          Button("Edit record", systemImage: "pencil") { sheet = .editDone(entry) }
          Button("Delete record", systemImage: "trash", role: .destructive) { deleting = true }
        }
        if showTaskLink, let taskID = entry.taskID, store.state.entry(taskID) != nil {
          NavigationLink("Open Task") { TaskDetailView(id: taskID) }
        }
      }
      .sheet(item: $sheet) { EditorSheet(route: $0) }
      .confirmationDialog("Delete this record?", isPresented: $deleting) {
        Button("Delete record", role: .destructive) { _ = store.apply { try $0.delete(entry.id) } }
      } message: {
        Text("Only the performed record is removed, not the task or lifecycle history. Current next start is unchanged.")
      }
  }
}
