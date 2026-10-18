import Foundation
import XCTest
@testable import PhaseCore

final class CriticalSemanticsTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testPhaseSpotlightUpsertRejectedAndLegacyFlagsFiltered() throws {
        for archived in [false, true] {
            var phase = Entry(kind: .phase, title: "Phase", now: t0)
            phase.isSpotlight = true
            phase.archived = archived
            var state = PhaseState()
            XCTAssertThrowsError(try state.upsert(phase))
            XCTAssertTrue(state.entries.isEmpty)
            state = PhaseState(entries: [phase])
            XCTAssertTrue(state.spotlight.isEmpty)
            let before = state
            XCTAssertThrowsError(try state.toggleSpotlight(phase.id))
            XCTAssertEqual(state, before)
        }
    }

    func testResumeUsesNonblankStartOtherwiseLatestPerformedText() throws {
        var task = Entry(kind: .task, title: "Task", now: t0)
        var done = Entry(kind: .done, now: t0)
        done.taskID = task.id
        done.text = "latest performed"
        for start in ["", " \n\t ", " \nnext action "] {
            task.nextStart = start
            let state = PhaseState(entries: [task, done])
            XCTAssertEqual(state.resume(taskID: task.id), start.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? done.text : start)
        }
        XCTAssertEqual(PhaseState().resume(taskID: UUID()), "")
    }

    func testWhitespaceDoneStartReplacesOldStartAndFallsBackToDone() throws {
        var task = Entry(kind: .task, title: "Task", now: t0)
        task.nextStart = "stale"
        var state = PhaseState(entries: [task])
        try state.addDone(taskID: task.id, text: "performed", nextStart: " \n\t ", date: t0, now: t0)
        XCTAssertEqual(state.entry(task.id)?.nextStart.trimmingCharacters(in: .whitespacesAndNewlines), "")
        XCTAssertEqual(state.resume(taskID: task.id), "performed")
    }

    func testPerformedDatesIgnoreEditsEventsAndCreationAcrossDSTMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let performed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 10, hour: 12)))
        let boundary = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 12)))
        let task = Entry(kind: .task, title: "Task", now: boundary)
        var state = PhaseState(entries: [task])
        try state.addDone(taskID: task.id, text: "latest", date: performed, now: boundary)
        let latest = try XCTUnwrap(state.latestDone(taskID: task.id))
        try state.addDone(taskID: task.id, text: "backfill", date: performed.addingTimeInterval(-100), now: boundary.addingTimeInterval(1000))
        try state.editDone(id: latest.id, text: "edited", notes: "", date: performed, now: boundary.addingTimeInterval(2000))
        try state.endTask(task.id, status: "completed", now: boundary.addingTimeInterval(3000))
        XCTAssertEqual(state.lastPerformed(taskID: task.id), performed)
        XCTAssertFalse(state.isDormant(taskID: task.id, now: boundary.addingTimeInterval(-0.001), calendar: calendar))
        XCTAssertTrue(state.isDormant(taskID: task.id, now: boundary, calendar: calendar))
        try state.delete(latest.id)
        XCTAssertEqual(state.lastPerformed(taskID: task.id), performed.addingTimeInterval(-100))
    }
}
