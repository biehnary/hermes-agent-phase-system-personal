import PhaseCore
import SwiftUI

struct PhasesView: View {
  @Environment(AppStore.self) private var store
  @AppStorage("v2.classifications.mode") private var mode = "phases"
  @AppStorage("v2.classifications.past") private var showPast = false
  @State private var sheet: EditorRoute?
  private var kind: EntryKind { mode == "areas" ? .area : .phase }
  private var entries: [Entry] {
    store.state.items(kind).filter {
      kind == .area || showPast || store.state.phaseStatus($0) == "active"
    }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }
  var body: some View {
    List {
      Section {
        Picker("Browse", selection: $mode) {
          Text("Phases").tag("phases"); Text("Areas").tag("areas")
        }.pickerStyle(.segmented)
        if kind == .phase { Toggle("Show past phases", isOn: $showPast) }
      }
      ForEach(entries) { EntryLink(entry: $0) }
      if entries.isEmpty { Text(kind == .phase ? "No phases" : "No areas").foregroundStyle(.secondary) }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(kind == .phase ? "Add Phase" : "Add Area", systemImage: "plus") {
          sheet = .entry(Entry(kind: kind))
        }.labelStyle(.iconOnly).help(kind == .phase ? "Add Phase" : "Add Area")
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
  }
}

struct ClassificationDetailView: View {
  @Environment(AppStore.self) private var store
  let id: UUID
  var readOnly = false
  @State private var sheet: EditorRoute?
  @State private var tasksLimit = 5
  @State private var historyLimit = 5
  @State private var phasesLimit = 5
  @State private var showPast = false
  private func linkedTasks(_ item: Entry) -> [Entry] {
    let phaseIDs = Set(store.state.items(.phase).filter { $0.areaID == item.id }.map(\.id))
    return store.state.items(.task).filter { task in
      item.kind == .phase ? task.phaseID == item.id
        : (task.phaseID.map { phaseIDs.contains($0) } ?? (task.areaID == item.id))
    }.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt }
  }
  var body: some View {
    Group {
      if let item = store.state.entry(id) {
        List {
          Section("Context") {
            if item.kind == .phase { Text(store.state.phaseStatus(item).capitalized).font(.caption).foregroundStyle(.secondary) }
            context("Description", item.text)
            if item.kind == .phase {
              context("Goal", item.goal)
              context("Current status", item.statusNote)
              context("Bottleneck", item.bottleneck)
              context("Expected change", item.expectedChange)
              if !item.resources.isEmpty { ResourceContent(text: item.resources) }
              context("Notes", item.notes)
            }
            if item.kind == .phase, let areaID = item.areaID, let area = store.state.entry(areaID) {
              if readOnly { Text(area.title).font(.caption).foregroundStyle(.secondary) }
              else { EntryLink(entry: area) }
            }
          }
          if !readOnly {
            if item.kind == .area {
              Section("Phases") {
                Toggle("Show past phases", isOn: $showPast)
                let phases = store.state.items(.phase).filter {
                  $0.areaID == id && (showPast || store.state.phaseStatus($0) == "active")
                }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                ForEach(Array(phases.prefix(phasesLimit))) { EntryLink(entry: $0) }
                MoreControls(total: phases.count, limit: $phasesLimit)
                Button("Add Phase", systemImage: "plus") {
                  var phase = Entry(kind: .phase)
                  phase.areaID = id
                  sheet = .entry(phase)
                }
              }
            }
            Section("Tasks") {
              let tasks = linkedTasks(item)
              ForEach(Array(tasks.prefix(tasksLimit))) { EntryLink(entry: $0, showLifecycle: true).listRowBackground(taskCardColor($0)) }
              MoreControls(total: tasks.count, limit: $tasksLimit)
              if item.kind == .phase && store.state.phaseStatus(item) == "active" {
                Button("Add Task", systemImage: "plus.rectangle") {
                  var task = Entry(kind: .task)
                  task.phaseID = id
                  sheet = .entry(task)
                }
              }
            }
            Section(item.kind == .area ? "Area continuity" : "Phase history") {
              let history = store.state.recordTimeline().filter { item.kind == .area ? $0.areaID == id : $0.phaseID == id }
              ForEach(Array(history.prefix(historyLimit))) { RecordRow(entry: $0) }
              if history.isEmpty { Text("No records").foregroundStyle(.secondary) }
              MoreControls(total: history.count, limit: $historyLimit)
            }
          }
        }
        .navigationTitle(item.title)
        .toolbar {
          if !readOnly {
            ToolbarItem(placement: .primaryAction) {
              Menu {
                Button("Edit", systemImage: "pencil") { sheet = .entry(item) }
                if item.kind == .phase {
                  if store.state.phaseStatus(item) == "active" {
                    Button("Complete Phase", systemImage: "checkmark.circle") { setStatus("completed") }
                    Button("Stop Phase", systemImage: "stop.circle") { setStatus("stopped") }
                  } else {
                    Button("Reopen Phase", systemImage: "arrow.uturn.backward") { setStatus("active") }
                  }
                }
              } label: { Label("Context actions", systemImage: "ellipsis.circle") }
            }
          }
        }
      } else { ContentUnavailableView("Context unavailable", systemImage: "questionmark.folder") }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
  }
  private func setStatus(_ status: String) { _ = store.apply { try $0.setPhaseStatus(id, status: status) } }
  @ViewBuilder private func context(_ title: String, _ value: String) -> some View {
    if !value.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Text(value).textSelection(.enabled)
      }.padding(.vertical, 3)
    }
  }
}

/// A sheet above the editor: closing it does not recreate or save the editor draft.
struct PhaseReferenceSheet: View {
  @Environment(\.dismiss) private var dismiss
  let id: UUID
  var body: some View {
    NavigationStack {
      ClassificationDetailView(id: id, readOnly: true)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
  }
}

struct InboxReferenceSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        ForEach(store.state.items(.inbox).sorted { $0.createdAt > $1.createdAt }) { entry in
          Text(entry.text).textSelection(.enabled)
        }
        if store.state.items(.inbox).isEmpty { Text("Inbox is empty").foregroundStyle(.secondary) }
      }.navigationTitle("Inbox reference")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
  }
}
