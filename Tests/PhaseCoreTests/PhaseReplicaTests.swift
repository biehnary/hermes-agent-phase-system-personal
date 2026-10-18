import Foundation
import XCTest
import PhaseCore

final class PhaseReplicaTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let low = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let high = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    func testWinnersResolveDuplicatesByTimestampRevisionAndPayloadInAnyOrder() throws {
        let entry = Entry(kind: .task, title: "A", id: low, now: t0)
        var changed = entry
        changed.title = "Z"
        let old = StoredEnvelope(id: low, value: entry, modifiedAt: t0, revisionID: high)
        let newerLowRevision = StoredEnvelope(id: low, value: entry, modifiedAt: t0.addingTimeInterval(1), revisionID: low)
        let newerHighRevision = StoredEnvelope(id: low, value: entry, modifiedAt: t0.addingTimeInterval(1), revisionID: high)
        let payloadTie = StoredEnvelope(id: low, value: changed, modifiedAt: t0.addingTimeInterval(1), revisionID: high)
        let rows = [old, newerLowRevision, newerHighRevision, payloadTie, old]
        XCTAssertEqual(try PhaseReplica.winners([old, newerLowRevision]), [newerLowRevision])
        XCTAssertEqual(try PhaseReplica.winners([newerHighRevision, newerLowRevision]), [newerHighRevision])
        for offset in rows.indices {
            let rotated = Array(rows[offset...]) + Array(rows[..<offset])
            XCTAssertEqual(try PhaseReplica.winners(rotated), [payloadTie])
            XCTAssertEqual(try PhaseReplica.winners(Array(rotated.reversed())), [payloadTie])
        }
    }

    func testTombstoneWinsExactTieAndOlderLiveRowsCannotResurrect() throws {
        let entry = Entry(kind: .task, title: "Task", id: low, now: t0)
        let live = StoredEnvelope(id: low, value: entry, modifiedAt: t0, revisionID: high)
        let deleted = StoredEnvelope(id: low, value: nil, modifiedAt: t0.addingTimeInterval(1), revisionID: low)
        var exactTie = live
        exactTie.modifiedAt = deleted.modifiedAt
        exactTie.revisionID = deleted.revisionID
        XCTAssertEqual(try PhaseReplica.winners([live, deleted, exactTie]), [deleted])
        XCTAssertEqual(try PhaseReplica.winners([exactTie, deleted, live]), [deleted])
        XCTAssertTrue(try PhaseReplica.state([deleted, live]).entries.isEmpty)
    }

    func testStateSortsWinnerPayloadsByIdentity() throws {
        let a = Entry(kind: .task, title: "A", id: low, now: t0)
        let b = Entry(kind: .task, title: "B", id: high, now: t0)
        let rows = [b, a].map { StoredEnvelope(id: $0.id, value: $0, modifiedAt: t0, revisionID: high) }
        XCTAssertEqual(try PhaseReplica.state(rows).entries, [a, b])
    }

    func testChangesAreMinimalAndPreserveRemoteSiblingAdditions() throws {
        let a = Entry(kind: .task, title: "A", id: low, now: t0)
        let b = Entry(kind: .task, title: "Remote sibling", id: high, now: t0)
        let c = Entry(kind: .task, title: "Unchanged", now: t0)
        let added = Entry(kind: .inbox, now: t0)
        var updated = a
        updated.title = "Edited locally"
        let existing = [a, b, c].map { StoredEnvelope(id: $0.id, value: $0, modifiedAt: t0, revisionID: high) }
        let old = PhaseState(entries: [a, c])
        let new = PhaseState(entries: [updated, c, added])
        let writes = try PhaseReplica.changes(from: old, to: new, existing: existing, now: t0.addingTimeInterval(10))
        XCTAssertEqual(Set(writes.map(\.id)), [a.id, added.id])
        XCTAssertEqual(writes.count, 2)
        let merged = try PhaseReplica.state(existing + writes)
        XCTAssertEqual(merged.entry(b.id), b)
        XCTAssertEqual(merged.entry(c.id), c)
        XCTAssertEqual(merged.entry(a.id), updated)
        XCTAssertTrue(try PhaseReplica.changes(from: new, to: new, existing: existing + writes, now: t0).isEmpty)
        let deleted = try PhaseReplica.changes(from: new, to: PhaseState(entries: [c, added]), existing: existing + writes, now: t0)
        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(deleted.first?.id, a.id)
        XCTAssertNil(deleted.first?.value)
        let afterDelete = try PhaseReplica.state(existing + writes + deleted)
        XCTAssertNil(afterDelete.entry(a.id))
        XCTAssertEqual(afterDelete.entry(b.id), b)
    }

    func testChangeTimestampsAreMonotonicPerKeyEvenWhenClockMovesBackward() throws {
        let a = Entry(kind: .task, title: "A", id: low, now: t0)
        let b = Entry(kind: .task, title: "B", id: high, now: t0)
        var updated = a
        updated.title = "Changed"
        let future = t0.addingTimeInterval(100)
        let existing = [StoredEnvelope(id: low, value: a, modifiedAt: future, revisionID: high), StoredEnvelope(id: high, value: nil, modifiedAt: t0.addingTimeInterval(-10), revisionID: high)]
        let writes = try PhaseReplica.changes(from: PhaseState(entries: [a]), to: PhaseState(entries: [updated, b]), existing: existing, now: t0)
        XCTAssertEqual(writes.first { $0.id == low }?.modifiedAt, future.addingTimeInterval(0.001))
        XCTAssertEqual(writes.first { $0.id == high }?.modifiedAt, t0)
        XCTAssertTrue(writes.allSatisfy { $0.revisionID != high })
        let deletion = try PhaseReplica.changes(from: PhaseState(entries: [updated]), to: PhaseState(), existing: existing + writes, now: t0)
        XCTAssertEqual(deletion.first?.modifiedAt, future.addingTimeInterval(0.001).addingTimeInterval(0.001))
    }

    func testChangesValidateDuplicateAndSharedIdentityBeforeWriting() throws {
        let a = Entry(kind: .task, title: "A", id: low, now: t0)
        let changedKind = Entry(kind: .phase, title: "Not same entity", id: low, now: t0)
        let old = PhaseState(entries: [a])
        XCTAssertThrowsError(try PhaseReplica.changes(from: old, to: PhaseState(entries: [changedKind]), existing: [], now: t0))
        XCTAssertThrowsError(try PhaseReplica.changes(from: PhaseState(entries: [a, a]), to: old, existing: [], now: t0))
        XCTAssertThrowsError(try PhaseReplica.changes(from: old, to: PhaseState(entries: [a, a]), existing: [], now: t0))
        let mismatch = StoredEnvelope(id: high, value: a, modifiedAt: t0, revisionID: high)
        XCTAssertThrowsError(try PhaseReplica.changes(from: old, to: old, existing: [mismatch], now: t0))
        XCTAssertThrowsError(try PhaseReplica.changes(from: old, to: old, existing: [], now: Date(timeIntervalSince1970: .infinity)))
    }

    /// Regression simulation of revision transport only, NOT a CloudKit test.
    func testThreeReplicaOfflineUnionConvergesWithIndependentStartsAndSpotlightOrder() throws {
        let a = Entry(kind: .task, title: "A", id: low, now: t0)
        let b = Entry(kind: .task, title: "B", id: high, now: t0)
        let base = PhaseState(entries: [a, b])
        let seeded = try PhaseReplica.changes(from: PhaseState(), to: base, existing: [], now: t0)
        var phone = base
        var mac = base
        try phone.toggleSpotlight(a.id, now: t0)
        try phone.toggleSpotlight(b.id, now: t0)
        try phone.reorderSpotlight([b.id, a.id], now: t0)
        try phone.addDone(taskID: a.id, text: "Phone performed", nextStart: "A continue", date: t0, now: t0)
        try mac.addDone(taskID: b.id, text: "Mac performed", nextStart: "B continue", date: t0, now: t0)
        let phoneRows = try PhaseReplica.changes(from: base, to: phone, existing: seeded, now: t0.addingTimeInterval(1))
        let macRows = try PhaseReplica.changes(from: base, to: mac, existing: seeded, now: t0.addingTimeInterval(2))
        let all = seeded + phoneRows + macRows
        let merged = try PhaseReplica.state(all)
        XCTAssertEqual(merged.items(.done).count, 2)
        XCTAssertEqual(merged.resume(taskID: a.id), "A continue")
        XCTAssertEqual(merged.resume(taskID: b.id), "B continue")
        // Same task B was changed on both devices. Whole-entry LWW intentionally
        // means Mac's newer unstarred B wins over the phone's B reorder.
        XCTAssertEqual(merged.spotlight.map(\.id), [a.id])
        let shuffled = try JSONDecoder().decode([StoredEnvelope].self, from: JSONEncoder().encode(all.reversed()))
        XCTAssertEqual(try PhaseReplica.state(shuffled), merged)
        XCTAssertEqual(try PhaseReplica.state(macRows + seeded + phoneRows + macRows), merged)
        var tablet = merged
        try tablet.toggleSpotlight(b.id, now: t0)
        try tablet.reorderSpotlight([b.id, a.id], now: t0)
        try tablet.addDone(taskID: a.id, text: "New blank hint", nextStart: "", date: t0.addingTimeInterval(5), now: t0)
        let tabletRows = try PhaseReplica.changes(from: merged, to: tablet, existing: all, now: t0.addingTimeInterval(3))
        let final = try PhaseReplica.state(all + tabletRows)
        XCTAssertEqual(final.spotlight.map(\.id), [b.id, a.id])
        XCTAssertEqual(final.resume(taskID: a.id), "New blank hint")
        XCTAssertEqual(final.resume(taskID: b.id), "B continue")
        XCTAssertEqual(final.items(.done).count, 3)
    }

    func testEnvelopeCodableIncludesTombstonesAndRevision() throws {
        let entry = Entry(kind: .task, title: "Task", now: t0)
        for value in [entry, nil] {
            let envelope = StoredEnvelope(id: entry.id, value: value, modifiedAt: t0, revisionID: high)
            let copy = try JSONDecoder().decode(StoredEnvelope.self, from: JSONEncoder().encode(envelope))
            XCTAssertEqual(copy.id, entry.id)
            XCTAssertEqual(copy.value, value)
            XCTAssertEqual(copy.modifiedAt, t0)
            XCTAssertEqual(copy.revisionID, high)
        }
    }
}
