import Foundation

/// One per-identity revision. A nil value is a durable deletion, not an absent row.
public struct StoredEnvelope: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var value: Entry?
    public var modifiedAt: Date
    public var revisionID: UUID

    public init(id: UUID, value: Entry?, modifiedAt: Date, revisionID: UUID) {
        self.id = id
        self.value = value
        self.modifiedAt = modifiedAt
        self.revisionID = revisionID
    }
}

public enum PhaseReplica {
    /// Returns one revision per identity, sorted by UUID. Latest date wins, then
    /// lexically greatest revision UUID. Exact ties prefer tombstones; live ties
    /// prefer lexically greatest sorted-key JSON bytes (all Entry fields).
    /// Rejects malformed identities/non-encodable payloads rather than silently
    /// making reconciliation depend on arrival order.
    public static func winners(_ envelopes: [StoredEnvelope]) throws -> [StoredEnvelope] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var selected: [UUID: (envelope: StoredEnvelope, payload: Data)] = [:]
        for row in envelopes {
            guard row.modifiedAt.timeIntervalSince1970.isFinite,
                  row.value == nil || row.value?.id == row.id else {
                throw PhaseError.invalid("저장 항목의 식별자와 날짜를 확인해 주세요.")
            }
            let payload = try encoder.encode(row.value)
            if let old = selected[row.id] {
                if row.modifiedAt < old.envelope.modifiedAt { continue }
                if row.modifiedAt == old.envelope.modifiedAt {
                    if row.revisionID.uuidString < old.envelope.revisionID.uuidString { continue }
                    if row.revisionID == old.envelope.revisionID {
                        if old.envelope.value == nil { continue }
                        if row.value != nil && !old.payload.lexicographicallyPrecedes(payload) { continue }
                    }
                }
            }
            selected[row.id] = (row, payload)
        }
        return selected.values.map(\.envelope).sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Write only identities touched by this transaction. Remote-only additions
    /// must not become local deletions. Revisions are immutable rows in SwiftData.
    public static func changes(from old: PhaseState, to new: PhaseState,
                               existing: [StoredEnvelope], now: Date = Date()) throws -> [StoredEnvelope] {
        guard now.timeIntervalSince1970.isFinite,
              Set(old.entries.map(\.id)).count == old.entries.count,
              Set(new.entries.map(\.id)).count == new.entries.count else {
            throw PhaseError.invalid("저장 날짜 또는 중복 항목을 확인해 주세요.")
        }
        let revisions = Dictionary(uniqueKeysWithValues: try winners(existing).map { ($0.id, $0) })
        let before = Dictionary(uniqueKeysWithValues: old.entries.map { ($0.id, $0) })
        let after = Dictionary(uniqueKeysWithValues: new.entries.map { ($0.id, $0) })
        var writes: [StoredEnvelope] = []
        for id in Set(before.keys).union(after.keys).sorted(by: { $0.uuidString < $1.uuidString }) {
            if let a = before[id], let b = after[id], a.kind != b.kind {
                throw PhaseError.invalid("항목 종류를 바꿀 수 없습니다.")
            }
            guard before[id] != after[id] else { continue }
            let timestamp = max(now, revisions[id]?.modifiedAt.addingTimeInterval(0.001) ?? now)
            let row = StoredEnvelope(id: id, value: after[id], modifiedAt: timestamp, revisionID: UUID())
            _ = try winners([row])
            writes.append(row)
        }
        return writes
    }

    public static func state(_ envelopes: [StoredEnvelope]) throws -> PhaseState {
        PhaseState(entries: try winners(envelopes).compactMap(\.value))
    }
}
