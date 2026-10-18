import Observation
import PhaseCore
import SwiftUI
import UniformTypeIdentifiers

@Observable final class UIPresentationState {
  var sheets: [UUID] = []
}

struct RootView: View {
  @Environment(AppStore.self) private var store
  @State private var tab: Screen = .spotlight
  @State private var sheet: EditorRoute?
  @State private var exporting = false
  @State private var presentations = UIPresentationState()

  enum Screen: String, CaseIterable, Identifiable {
    case spotlight = "Spotlight"
    case tasks = "Tasks"
    case phases = "Phases"
    case daily = "Daily Log"
    var id: Self { self }
    var symbol: String {
      switch self {
      case .spotlight: "star"
      case .tasks: "list.bullet"
      case .phases: "square.stack"
      case .daily: "calendar"
      }
    }
  }

  var body: some View {
    GeometryReader { geometry in
      if geometry.size.width >= 900 {
        NavigationSplitView {
          List(Screen.allCases) { screen in
            Button {
              tab = screen
            } label: {
              HStack {
                Label(screen.rawValue, systemImage: screen.symbol)
                Spacer()
                if screen == tab { Image(systemName: "checkmark").accessibilityLabel("Selected") }
              }
            }.buttonStyle(.plain).padding(.vertical, 5)
          }.navigationTitle("Phase System")
        } detail: {
          screenView(tab).id(tab)
        }
      } else {
        TabView(selection: $tab) {
          ForEach(Screen.allCases) { screen in
            screenView(screen)
              .tabItem { Label(screen.rawValue, systemImage: screen.symbol) }
              .tag(screen)
          }
        }
      }
    }
    .sheet(item: $sheet) { EditorSheet(route: $0) }
    .fileExporter(
      isPresented: $exporting, document: MarkdownDocument(text: store.exportText),
      contentType: .plainText, defaultFilename: "Phase-System.md"
    ) { result in
      if case .failure(let error) = result { store.error = error.localizedDescription }
    }
    .storeErrorAlert(enabled: presentations.sheets.isEmpty)
    .environment(presentations)
  }

  private func screenView(_ screen: Screen) -> some View {
    NavigationStack {
      Group {
        switch screen {
        case .spotlight: SpotlightView()
        case .tasks: TasksView()
        case .phases: PhasesView()
        case .daily: DailyLogView()
        }
      }
      .navigationTitle(screen.rawValue)
      .toolbar {
        if screen == .phases {
          ToolbarItem(placement: .secondaryAction) {
            Menu {
              Button("Export all Markdown", systemImage: "square.and.arrow.up") { exporting = true }
            } label: {
              Label("Export actions", systemImage: "square.and.arrow.up")
            }
          }
        }
      }
    }
    .safeAreaInset(edge: .bottom, alignment: .trailing) {
      Image(systemName: "plus")
        .font(.title3)
        .frame(width: 48, height: 48)
        .background(.regularMaterial, in: Circle())
        .overlay(Circle().stroke(.secondary.opacity(0.3)))
        .contentShape(Circle())
        .gesture(
          LongPressGesture(minimumDuration: 0.5)
            .exclusively(before: TapGesture())
            .onEnded { value in
              switch value {
              case .first(true): sheet = .inboxList
              case .second: sheet = .entry(Entry(kind: .inbox))
              default: break
              }
            }
        )
        .padding()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Add to Inbox")
        .accessibilityHint("Tap to capture. Hold to open Inbox.")
        .accessibilityAction { sheet = .entry(Entry(kind: .inbox)) }
        .accessibilityAction(named: Text("Open Inbox")) { sheet = .inboxList }
        .accessibilityIdentifier("inboxDump")
    }
  }
}

struct MarkdownDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  var text: String
  init(text: String) { self.text = text }
  init(configuration: ReadConfiguration) throws {
    text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

struct StoreErrorAlert: ViewModifier {
  @Environment(AppStore.self) private var store
  var enabled: Bool
  func body(content: Content) -> some View {
    content.alert(
      "Could not save",
      isPresented: Binding(
        get: { enabled && store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }
}
extension View {
  func storeErrorAlert(enabled: Bool = true) -> some View {
    modifier(StoreErrorAlert(enabled: enabled))
  }
}

struct EntryLink: View {
  let entry: Entry
  var showLifecycle = false
  var body: some View {
    NavigationLink {
      if entry.kind == .task {
        TaskDetailView(id: entry.id)
      } else {
        ClassificationDetailView(id: entry.id)
      }
    } label: {
      EntryLabel(entry: entry, showLifecycle: showLifecycle)
    }
  }
}

struct EntryLabel: View {
  @Environment(AppStore.self) private var store
  let entry: Entry
  var showLifecycle = false
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(entry.title).foregroundStyle(.primary)
      }
      if entry.kind == .task {
        Text(entry.taskKind == "quick" ? "Quick" : "General").font(.caption).foregroundStyle(
          .secondary)
        if showLifecycle || entry.lifecycle != "active" {
          Text(entry.lifecycle.capitalized).font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        if store.state.isDormant(taskID: entry.id) {
          Text("No record in the past month").font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text(entry.kind == .phase ? store.state.phaseStatus(entry).capitalized : "Area").font(.caption)
          .foregroundStyle(.secondary)
        if entry.kind == .phase, let area = entry.areaID.flatMap({ store.state.entry($0) }) {
          Text(area.title).font(.caption).foregroundStyle(.secondary)
        }
      }
    }.padding(.vertical, 4)
  }
}

struct SpotlightView: View {
  @Environment(AppStore.self) private var store
  @State private var selection = Set<UUID>()
  @State private var removed = Set<UUID>()
  @State private var previousOrder: [UUID] = []
  #if os(iOS)
    @State private var editMode: EditMode = .inactive
  #endif
  var body: some View {
    spotlightList
      .safeAreaInset(edge: .top) {
        Text(store.syncSummary).font(.caption2).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.vertical, 4)
      }
      .safeAreaInset(edge: .bottom) {
        if !removed.isEmpty {
          HStack {
            Text("Removed from Spotlight").font(.caption)
            Spacer()
            Button("Undo", systemImage: "arrow.uturn.backward") { undoRemoval() }
            Button("Dismiss", systemImage: "xmark") { removed = []; previousOrder = [] }
              .labelStyle(.iconOnly).help("Dismiss")
          }.padding().background(.regularMaterial)
        }
      }
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .secondaryAction) { EditButton() }
        #endif
        ToolbarItem(placement: .primaryAction) {
          if !selection.isEmpty {
            Button("Remove selected", systemImage: "star.slash") { remove(selection) }
              .labelStyle(.iconOnly).help("Remove selected from Spotlight")
          }
        }
      }
      #if os(iOS)
        .environment(\.editMode, $editMode)
      #endif
  }
  private var spotlightList: some View {
    // Native selection preserves two-finger List selection where supported by iOS.
    // No custom single-finger drag gesture competes with the reorder handles.
    List(selection: $selection) {
      if store.state.spotlight.isEmpty { Text("Star tasks to keep them here.").foregroundStyle(.secondary) }
      ForEach(store.state.spotlight) { entry in
        NavigationLink {
          TaskDetailView(id: entry.id)
        } label: {
          VStack(alignment: .leading, spacing: 5) {
            Text("\(areaTitle(entry)) / \(entry.phaseID.flatMap { store.state.entry($0)?.title } ?? "Unassigned")")
              .font(.caption).foregroundStyle(.secondary)
            Text(entry.title).foregroundStyle(.primary)
            Text(entry.taskKind == "quick" ? "Quick" : "General").font(.caption2).foregroundStyle(.secondary)
            let resume = store.state.resume(taskID: entry.id)
            if !resume.isEmpty { Text(resume).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
          }.padding(.vertical, 4)
        }
        .tag(entry.id)
        .listRowBackground(taskCardColor(entry))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button("Remove from Spotlight", systemImage: "star.slash") { remove([entry.id]) }.tint(.gray)
        }
        .accessibilityAction(named: Text("Remove from Spotlight")) { remove([entry.id]) }
      }
      .onMove { source, target in
        var ids = store.state.spotlight.map(\.id)
        ids.move(fromOffsets: source, toOffset: target)
        _ = store.apply { try $0.reorderSpotlight(ids) }
      }
    }
  }
  private func areaTitle(_ task: Entry) -> String {
    let id = task.phaseID.flatMap { store.state.entry($0)?.areaID } ?? task.areaID
    return id.flatMap { store.state.entry($0)?.title } ?? "Unassigned"
  }
  private func remove(_ ids: Set<UUID>) {
    let order = store.state.spotlight.map(\.id)
    let targets = ids.intersection(order)
    guard !targets.isEmpty else { return }
    var actuallyRemoved = Set<UUID>()
    if store.apply({ state in
      for id in targets {
        if state.entry(id)?.isSpotlight == true {
          try state.toggleSpotlight(id)
          actuallyRemoved.insert(id)
        }
      }
    }) {
      removed = actuallyRemoved; previousOrder = order; selection.subtract(targets)
    }
  }
  private func undoRemoval() {
    if store.apply({ state in
      for id in removed {
        if let task = state.entry(id), task.lifecycle == "active", !task.archived, !task.isSpotlight {
          try state.toggleSpotlight(id)
        }
      }
      let current = state.spotlight.map(\.id)
      let existing = Set(current)
      let original = previousOrder.filter { existing.contains($0) }
      let restored = Set(original)
      try state.reorderSpotlight(original + current.filter { !restored.contains($0) })
    }) { removed = []; previousOrder = [] }
  }
}
