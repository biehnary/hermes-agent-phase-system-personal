import PhaseCore
import SwiftUI

enum EditorRoute: Identifiable {
  case entry(Entry)
  case done(UUID?)
  case editDone(Entry)
  case inboxList
  var id: String {
    switch self {
    case .entry(let entry): "entry-\(entry.id)"
    case .done(let id): "done-\(id?.uuidString ?? "unlinked")"
    case .editDone(let entry): "done-edit-\(entry.id)"
    case .inboxList: "inbox-list"
    }
  }
}

struct EditorSheet: View {
  @Environment(UIPresentationState.self) private var presentations
  @State private var presentationID = UUID()
  let route: EditorRoute
  var body: some View {
    NavigationStack {
      switch route {
      case .entry(let entry): EntryEditor(entry: entry)
      case .done(let id): DoneEditor(taskID: id)
      case .editDone(let entry): DoneEditor(taskID: entry.taskID, existing: entry)
      case .inboxList: InboxView()
      }
    }
    .frame(idealWidth: 640, idealHeight: 720)
    .storeErrorAlert(enabled: presentations.sheets.last == presentationID)
    .onAppear {
      if !presentations.sheets.contains(presentationID) {
        presentations.sheets.append(presentationID)
      }
    }
    .onDisappear { presentations.sheets.removeAll { $0 == presentationID } }
  }
}

struct EntryEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var draft: Entry
  @State private var showPhaseReference = false
  @State private var showInboxReference = false
  init(entry: Entry) {
    var value = entry
    if value.kind == .phase && value.archived && value.lifecycle == "active" { value.lifecycle = "completed" }
    _draft = State(initialValue: value)
  }

  private var eligiblePhases: [Entry] {
    store.state.items(.phase).filter { store.state.phaseStatus($0) == "active" || $0.id == draft.phaseID }
      .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }

  var body: some View {
    Form {
      if draft.kind == .inbox {
        Section("Inbox dump") {
          TextField("Capture anything", text: $draft.text, axis: .vertical).lineLimit(6...16)
        }
      } else {
        Section("\(draft.kind.rawValue.capitalized)") {
          TextField("Title", text: $draft.title, axis: .vertical)
          TextField("Description", text: $draft.text, axis: .vertical)
        }
        if draft.kind == .task {
          Section("Management") {
            Picker("Kind", selection: $draft.taskKind) {
              Text("General").tag("general")
              Text("Quick").tag("quick")
            }
            Picker("Phase", selection: $draft.phaseID) {
              Text("Unassigned").tag(nil as UUID?)
              ForEach(store.state.items(.area).sorted { $0.title < $1.title }) { area in
                Section(area.title) {
                  ForEach(eligiblePhases.filter { $0.areaID == area.id }) { phase in
                    Text(phase.title + (store.state.phaseStatus(phase) == "active" ? "" : " · \(store.state.phaseStatus(phase).capitalized)"))
                      .tag(Optional(phase.id))
                  }
                }
              }
              Section("No area") {
                ForEach(eligiblePhases.filter { $0.areaID == nil }) { phase in
                  Text(phase.title + (store.state.phaseStatus(phase) == "active" ? "" : " · \(store.state.phaseStatus(phase).capitalized)"))
                    .tag(Optional(phase.id))
                }
              }
            }
            if draft.phaseID != nil {
              Button("Phase reference", systemImage: "doc.text.magnifyingglass") { showPhaseReference = true }
            }
            Text("Changing phase preserves previous records in their original phase and area.")
              .font(.caption).foregroundStyle(.secondary)
          }
          Section("Resume & resources") {
            if store.state.entry(draft.id) != nil {
              TextField("Next start", text: $draft.nextStart, axis: .vertical)
            }
            TextField("Resources / links", text: $draft.resources, axis: .vertical)
            TextField("Notes", text: $draft.notes, axis: .vertical)
          }
        } else {
          if draft.kind == .phase {
            Section("Context") {
              TextField("Goal", text: $draft.goal, axis: .vertical)
              TextField("Current status", text: $draft.statusNote, axis: .vertical)
              TextField("Bottleneck", text: $draft.bottleneck, axis: .vertical)
              TextField("Expected change", text: $draft.expectedChange, axis: .vertical)
              TextField("Resources / links", text: $draft.resources, axis: .vertical)
              TextField("Notes", text: $draft.notes, axis: .vertical)
            }
          }
          if draft.kind == .phase {
            Section("Light classification") {
              Picker("Area", selection: $draft.areaID) {
                Text("No area").tag(nil as UUID?)
                ForEach(store.state.items(.area)) { area in
                  Text(area.title + (area.archived ? " · Archived" : "")).tag(Optional(area.id))
                }
              }
              Text(
                "Area is a lightweight classification, not a task schedule. Previous records keep their captured area."
              ).font(.caption).foregroundStyle(.secondary)
            }
          }
          Section {
            if draft.kind == .phase {
              Picker("Status", selection: $draft.lifecycle) {
                Text("Active").tag("active")
                Text("Completed").tag("completed")
                Text("Stopped").tag("stopped")
              }
              Text("Closing a phase never ends or moves its tasks.").font(.caption).foregroundStyle(.secondary)
              Button("Inbox reference", systemImage: "tray") { showInboxReference = true }
            }
          }
        }
      }
    }
    .navigationTitle(
      draft.kind == .inbox ? "Inbox dump" : "Edit \(draft.kind.rawValue.capitalized)"
    )
    .sheet(isPresented: $showPhaseReference) {
      if let id = draft.phaseID { PhaseReferenceSheet(id: id) }
    }
    .sheet(isPresented: $showInboxReference) { InboxReferenceSheet() }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          var value = draft
          if value.kind == .phase { value.archived = value.lifecycle != "active" }
          if value.kind == .task {
            // Resolve the current area through the phase when recording,
            // rather than pinning a stale area onto a movable task.
            value.areaID = nil
          }
          if store.state.entry(value.id) == nil {
            value.rank = (store.state.items(value.kind).map(\.rank).max() ?? -1) + 1
          }
          if store.apply({ try $0.upsert(value) }) { dismiss() }
        }
        .disabled(
          (draft.kind == .inbox ? draft.text : draft.title).trimmingCharacters(
            in: .whitespacesAndNewlines
          ).isEmpty)
      }
    }
  }
}

struct DoneEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let taskID: UUID?
  let existing: Entry?
  @State private var text: String
  @State private var notes: String
  @State private var nextStart = ""
  @State private var date: Date
  @State private var showPhaseReference = false

  init(taskID: UUID?, existing: Entry? = nil) {
    self.taskID = taskID
    self.existing = existing
    _text = State(initialValue: existing?.text ?? "")
    _notes = State(initialValue: existing?.notes ?? "")
    _date = State(initialValue: existing?.date ?? Date())
  }

  var body: some View {
    Form {
      if let taskID, let task = store.state.entry(taskID) {
        Section {
          Text(task.title)
          if task.phaseID != nil {
            Button("Phase reference", systemImage: "doc.text.magnifyingglass") { showPhaseReference = true }
          }
        }
      }
      Section("Performed") {
        TextField("What did you do?", text: $text, axis: .vertical).lineLimit(3...12)
        TextField("Notes (optional)", text: $notes, axis: .vertical)
        DatePicker(
          "Performed date", selection: $date, displayedComponents: [.date, .hourAndMinute])
      }
      if existing == nil && taskID != nil {
        Section("Next start (optional)") {
          TextField("Where to resume", text: $nextStart, axis: .vertical)
          Text("Leave blank to discard the previous hint and use the latest Done text.").font(
            .caption
          ).foregroundStyle(
            .secondary)
        }
      }
      if existing != nil {
        Text("Editing this record does not change the task's current starting point.").font(
          .caption
        ).foregroundStyle(.secondary)
      }
    }
    .navigationTitle(existing == nil ? "Record Done" : "Edit Done")
    .sheet(isPresented: $showPhaseReference) {
      if let id = taskID.flatMap({ store.state.entry($0)?.phaseID }) { PhaseReferenceSheet(id: id) }
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          let success = store.apply { state in
            if let existing {
              try state.editDone(id: existing.id, text: text, notes: notes, date: date)
            } else {
              try state.addDone(
                taskID: taskID, text: text, notes: notes, nextStart: nextStart, date: date)
            }
          }
          if success { dismiss() }
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }
}

struct InboxView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var sheet: EditorRoute?
  @State private var deleting: Entry?
  var body: some View {
    List {
      if store.state.items(.inbox).isEmpty { Text("Inbox is empty.").foregroundStyle(.secondary) }
      ForEach(store.state.items(.inbox).sorted { $0.createdAt > $1.createdAt }) { entry in
        VStack(alignment: .leading, spacing: 8) {
          Text(entry.text)
          Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = entry }
              .labelStyle(.iconOnly).help("Delete inbox item").tint(.red)
            Button("Edit", systemImage: "pencil") { sheet = .entry(entry) }
              .labelStyle(.iconOnly).help("Edit inbox item").tint(.blue)
          }
          .contextMenu {
            Button("Edit", systemImage: "pencil") { sheet = .entry(entry) }
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = entry }
          }
      }
    }
    .navigationTitle("Inbox")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
      ToolbarItem(placement: .primaryAction) {
        Button("Capture", systemImage: "plus") { sheet = .entry(Entry(kind: .inbox)) }
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
    .confirmationDialog(
      "Delete inbox item?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete", role: .destructive) {
        if let deleting { _ = store.apply { try $0.delete(deleting.id) } }
        deleting = nil
      }
    }
  }
}
