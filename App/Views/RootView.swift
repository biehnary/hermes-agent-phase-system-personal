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
        ToolbarItemGroup(placement: .primaryAction) {
          Menu {
            Button("Add Task", systemImage: "plus.rectangle") { sheet = .entry(Entry(kind: .task)) }
            Button("Record Done", systemImage: "checkmark") { sheet = .done(nil) }
            Button("Inbox", systemImage: "tray") { sheet = .inboxList }
            Divider()
            Button("Export all Markdown", systemImage: "square.and.arrow.up") { exporting = true }
          } label: {
            Label("Actions", systemImage: "ellipsis.circle")
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
  var body: some View {
    NavigationLink {
      if entry.kind == .task {
        TaskDetailView(id: entry.id)
      } else {
        ClassificationDetailView(id: entry.id)
      }
    } label: {
      EntryLabel(entry: entry)
    }
  }
}

struct EntryLabel: View {
  @Environment(AppStore.self) private var store
  let entry: Entry
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(entry.title).foregroundStyle(.primary)
        if entry.kind == .task && entry.isSpotlight {
          Image(systemName: "star.fill").font(.caption).accessibilityLabel("In Spotlight")
        }
      }
      if entry.kind == .task {
        Text(entry.taskKind == "quick" ? "Quick" : "General").font(.caption).foregroundStyle(
          .secondary)
        if entry.lifecycle != "active" {
          Text(entry.lifecycle.capitalized).font(.caption).foregroundStyle(.secondary)
        }
        if store.state.isDormant(taskID: entry.id) {
          Text("No record in the past month").font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text(entry.kind.rawValue.capitalized + (entry.archived ? " · Archived" : "")).font(.caption)
          .foregroundStyle(.secondary)
      }
    }.padding(.vertical, 4)
  }
}

struct SpotlightView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    List {
      if store.state.spotlight.isEmpty {
        Text("Star tasks to keep them here.").foregroundStyle(.secondary)
      }
      ForEach(store.state.spotlight) { entry in
        NavigationLink {
          TaskDetailView(id: entry.id)
        } label: {
          VStack(alignment: .leading, spacing: 5) {
            Text(entry.title).foregroundStyle(.primary)
            Text(entry.phaseID.flatMap { store.state.entry($0)?.title } ?? "Unassigned")
              .font(.caption).foregroundStyle(.secondary)
            let resume = store.state.resume(taskID: entry.id)
            Text(resume.isEmpty ? "No starting point recorded." : resume)
              .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
          }.padding(.vertical, 4)
        }
        .contextMenu {
          Button("Move up", systemImage: "arrow.up") { shift(entry.id, by: -1) }
            .disabled(store.state.spotlight.first?.id == entry.id)
          Button("Move down", systemImage: "arrow.down") { shift(entry.id, by: 1) }
            .disabled(store.state.spotlight.last?.id == entry.id)
        }
      }
      .onMove { source, target in
        var ids = store.state.spotlight.map(\.id)
        ids.move(fromOffsets: source, toOffset: target)
        _ = store.apply { try $0.reorderSpotlight(ids) }
      }
      Section { Text(store.syncSummary).font(.caption).foregroundStyle(.secondary) }
    }
    .toolbar {
      #if os(iOS)
        ToolbarItem(placement: .secondaryAction) { EditButton() }
      #endif
    }
  }
  private func shift(_ id: UUID, by delta: Int) {
    var ids = store.state.spotlight.map(\.id)
    guard let index = ids.firstIndex(of: id), ids.indices.contains(index + delta) else { return }
    ids.swapAt(index, index + delta)
    _ = store.apply { try $0.reorderSpotlight(ids) }
  }
}
