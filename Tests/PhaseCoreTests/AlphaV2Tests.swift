import XCTest
@testable import PhaseCore

final class AlphaV2Tests: XCTestCase {
    func testWeeklyAreaDaysCountDistinctDatesAndCapturedAreaOnly() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 172800)
        let interval = DateInterval(start: day, duration: 7 * 86400)
        var state = PhaseState()
        let area = Entry(kind: .area, title: "Studio")
        try state.upsert(area)
        var phase = Entry(kind: .phase, title: "Alpha")
        phase.areaID = area.id
        try state.upsert(phase)
        var task = Entry(kind: .task, title: "Work")
        task.phaseID = phase.id
        try state.upsert(task)
        try state.addDone(taskID: task.id, text: "One", date: day)
        try state.addDone(taskID: task.id, text: "Two", date: day.addingTimeInterval(100))
        try state.addDone(taskID: task.id, text: "Three", date: day.addingTimeInterval(86400))
        try state.addDone(taskID: nil, text: "Independent", date: day)
        try state.addDone(taskID: nil, text: "Boundary excluded", date: interval.end)
        try state.endTask(task.id, status: "stopped", now: day.addingTimeInterval(2 * 86400))
        let summary = state.performedAreaDays(in: interval, calendar: calendar)
        XCTAssertEqual(summary.first { $0.areaID == area.id }?.days, 2)
        XCTAssertEqual(summary.first { $0.areaID == nil }?.days, 1)
        task.phaseID = nil
        task.lifecycle = "stopped"
        try state.upsert(task)
        XCTAssertEqual(state.performedAreaDays(in: interval, calendar: calendar), summary)
    }

    func testFinalDoneIsAtomicAndCombinedOnlyForDisplay() throws {
        var state = PhaseState()
        let task = Entry(kind: .task, title: "Finish")
        try state.upsert(task)
        let now = Date(timeIntervalSince1970: 1000)
        try state.endTask(task.id, status: "completed", finalDone: "Shipped", now: now)
        XCTAssertEqual(state.items(.done).count, 1)
        XCTAssertEqual(state.items(.event).count, 1)
        XCTAssertEqual(state.recordTimeline().count, 1)
        XCTAssertEqual(state.recordTimeline().first?.kind, .done)
        XCTAssertEqual(state.lifecycleLabel(for: state.items(.done)[0]), "completed")
        XCTAssertEqual(state.doneDays().count, 1)
        let before = state
        XCTAssertThrowsError(try state.endTask(task.id, status: "stopped", finalDone: "Again"))
        XCTAssertEqual(state, before)
        try state.delete(state.items(.done)[0].id)
        XCTAssertEqual(state.recordTimeline().first?.kind, .event)
        try state.reopenTask(task.id)
        try state.endTask(task.id, status: "stopped", finalDone: "   ")
        XCTAssertTrue(state.items(.done).isEmpty)
    }

    func testOldPayloadAndNewAssociationRoundTrip() throws {
        let entry = Entry(kind: .phase, title: "Old")
        let data = try JSONEncoder().encode(entry)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "linkedDoneID")
        let old = try JSONDecoder().decode(Entry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.linkedDoneID)
        XCTAssertEqual(old, entry)
    }

    func testPhaseLifecycleAndLegacyArchiveDoNotEndTasks() throws {
        var state = PhaseState()
        var phase = Entry(kind: .phase, title: "Context")
        phase.archived = true
        try state.upsert(phase)
        XCTAssertEqual(state.phaseStatus(phase), "completed")
        var task = Entry(kind: .task, title: "Work")
        task.phaseID = phase.id
        try state.upsert(task)
        try state.setPhaseStatus(phase.id, status: "stopped")
        XCTAssertEqual(state.phaseStatus(state.entry(phase.id)!), "stopped")
        XCTAssertEqual(state.currentTasks().map(\.id), [task.id])
        try state.setPhaseStatus(phase.id, status: "active")
        XCTAssertFalse(state.entry(phase.id)!.archived)
        XCTAssertThrowsError(try state.setPhaseStatus(phase.id, status: "invalid"))
    }
}
