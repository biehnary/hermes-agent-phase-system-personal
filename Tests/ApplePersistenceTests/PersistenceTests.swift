import Foundation
import SwiftData
import XCTest
import PhaseCore
@testable import PhaseSystemMac

/// Run on macOS via Scripts/build-apple.sh test. Not runnable on Linux.
@MainActor final class PersistenceTests: XCTestCase {
    func testDiskReopenRetainsDoneNextStartAndSpotlightOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let a = Entry(kind: .task, title: "A")
        let b = Entry(kind: .task, title: "B")
        do {
            let store = try AppStore(container: AppStore.makeContainer(containerID: nil, url: url), cloudEnabled: false)
            XCTAssertTrue(store.apply {
                try $0.upsert(a); try $0.upsert(b)
                try $0.toggleSpotlight(a.id); try $0.toggleSpotlight(b.id)
                try $0.reorderSpotlight([b.id, a.id])
                try $0.addDone(taskID: a.id, text: "Performed", nextStart: "Continue")
            })
        }
        let reopened = try AppStore(container: AppStore.makeContainer(containerID: nil, url: url), cloudEnabled: false)
        XCTAssertEqual(reopened.state.spotlight.map(\.id), [b.id, a.id])
        XCTAssertEqual(reopened.state.resume(taskID: a.id), "Continue")
        XCTAssertEqual(reopened.state.history(taskID: a.id).map(\.text), ["Performed"])
    }

    func testFailedSaveRollsBackMemoryAndDiskAndCanRetry() throws {
        let container = try AppStore.makeContainer(containerID: nil, inMemory: true)
        let store = try AppStore(container: container, cloudEnabled: false)
        let task = Entry(kind: .task, title: "Task")
        store.beforeSave = { throw PhaseError.invalid("Injected disk error") }
        XCTAssertFalse(store.apply { try $0.upsert(task) })
        XCTAssertNil(store.state.entry(task.id))
        XCTAssertNotNil(store.error)
        let reader = try AppStore(container: container, cloudEnabled: false)
        XCTAssertTrue(reader.state.entries.isEmpty)
        store.beforeSave = nil
        XCTAssertTrue(store.apply { try $0.upsert(task) })
        reader.refresh()
        XCTAssertNotNil(reader.state.entry(task.id))
    }

    func testSeparateContextRefreshAndTombstonePreventResurrection() throws {
        let container = try AppStore.makeContainer(containerID: nil, inMemory: true)
        let writer = try AppStore(container: container, cloudEnabled: false)
        let reader = try AppStore(container: container, cloudEnabled: false)
        var inbox = Entry(kind: .inbox)
        inbox.text = "Offline capture"
        XCTAssertTrue(writer.apply { try $0.upsert(inbox) })
        reader.refresh()
        XCTAssertEqual(reader.state.entry(inbox.id)?.text, inbox.text)
        XCTAssertTrue(writer.apply { try $0.delete(inbox.id) })
        reader.refresh()
        XCTAssertNil(reader.state.entry(inbox.id))
        let rows = try ModelContext(container).fetch(FetchDescriptor<RevisionEntity>())
        XCTAssertEqual(rows.count, 2) // immutable live revision plus durable tombstone
    }
}
