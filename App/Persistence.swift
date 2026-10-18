import CloudKit
import CoreData
import Foundation
import Observation
import PhaseCore
import SwiftData

/// Append-only revisions avoid CloudKit field-wise merging of a partly changed
/// task. No uniqueness constraints or required relationships (CloudKit compatible).
/// Tombstones are kept so a delayed offline revision cannot resurrect a deletion.
@Model final class RevisionEntity {
    var identity: String = ""
    var revision: String = ""
    var modifiedAt: Date = Date(timeIntervalSince1970: 0)
    var payload: Data?

    init(_ envelope: StoredEnvelope) throws {
        identity = envelope.id.uuidString
        revision = envelope.revisionID.uuidString
        modifiedAt = envelope.modifiedAt
        payload = try envelope.value.map { try JSONEncoder().encode($0) }
    }

    func envelope() throws -> StoredEnvelope {
        guard let id = UUID(uuidString: identity), let revisionID = UUID(uuidString: revision) else {
            throw PhaseError.invalid("저장된 기록의 식별자를 읽을 수 없습니다. 데이터를 지우지 말고 지원을 요청해 주세요.")
        }
        return StoredEnvelope(id: id, value: try payload.map { try JSONDecoder().decode(Entry.self, from: $0) },
                              modifiedAt: modifiedAt, revisionID: revisionID)
    }
}

@MainActor @Observable final class AppStore {
    private(set) var state: PhaseState = PhaseState()
    var error: String?
    private(set) var syncSummary: String
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let cloudEnabled: Bool
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    // Test fault injection occurs before the real save, never used in shipping UI.
    @ObservationIgnored var beforeSave: (() throws -> Void)?

    static func makeContainer(containerID: String?, url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([RevisionEntity.self])
        let cloudDatabase: ModelConfiguration.CloudKitDatabase
        if let containerID { cloudDatabase = .private(containerID) } else { cloudDatabase = .none }
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("PhaseSystem", schema: schema, url: url,
                                               cloudKitDatabase: cloudDatabase)
        } else {
            configuration = ModelConfiguration("PhaseSystem", schema: schema,
                                               isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: cloudDatabase)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    init(container: ModelContainer, cloudEnabled: Bool) throws {
        self.container = container
        self.cloudEnabled = cloudEnabled
        syncSummary = cloudEnabled ? "기기에 저장 · iCloud 상태 확인 중" : "기기에 저장 · 로컬 빌드 (iCloud 꺼짐)"
        state = try PhaseReplica.state(Self.read(container))
        if cloudEnabled {
            observers.append(NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
            ) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }
                let ended = event.endDate != nil
                let succeeded = event.succeeded
                let message = event.error?.localizedDescription
                let operation: String
                switch event.type {
                case .setup: operation = "설정"
                case .import: operation = "받기"
                case .export: operation = "보내기"
                @unknown default: operation = "처리"
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let message {
                        self.syncSummary = "기기에 저장 · iCloud \(operation) 실패: \(message)"
                    } else if ended && succeeded {
                        self.syncSummary = "기기에 저장 · iCloud \(operation) 완료 (다른 기기 수신 보장은 아님)"
                    } else {
                        self.syncSummary = "기기에 저장 · iCloud \(operation) 중"
                    }
                    self.refresh()
                }
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    private static func read(_ container: ModelContainer) throws -> [StoredEnvelope] {
        // Fresh contexts avoid a long-lived registered-object cache after imports.
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try context.fetch(FetchDescriptor<RevisionEntity>()).map { try $0.envelope() }
    }

    @discardableResult func apply(_ change: (inout PhaseState) throws -> Void) -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let rows = try context.fetch(FetchDescriptor<RevisionEntity>()).map { try $0.envelope() }
            let baseline = try PhaseReplica.state(rows)
            var proposed = baseline
            try change(&proposed)
            let writes = try PhaseReplica.changes(from: baseline, to: proposed, existing: rows)
            let merged = try PhaseReplica.state(rows + writes)
            for write in writes { context.insert(try RevisionEntity(write)) }
            try beforeSave?()
            try context.save()
            state = merged
            error = nil
            if !cloudEnabled { syncSummary = "기기에 저장 · 로컬 빌드 (iCloud 꺼짐)" }
            return true
        } catch {
            context.rollback()
            self.error = error.localizedDescription
            return false
        }
    }

    func refresh() {
        do {
            let fresh = try PhaseReplica.state(Self.read(container))
            if fresh != state { state = fresh }
        } catch { self.error = error.localizedDescription }
    }

    func checkAccount(containerID: String) async {
        do {
            let status = try await CKContainer(identifier: containerID).accountStatus()
            if status != .available {
                syncSummary = "기기에 저장 · iCloud 계정을 사용할 수 없음 (네트워크/계정 설정 확인)"
            }
        } catch { syncSummary = "기기에 저장 · iCloud 계정 확인 실패: \(error.localizedDescription)" }
    }

    var exportText: String { state.markdown() }
}
