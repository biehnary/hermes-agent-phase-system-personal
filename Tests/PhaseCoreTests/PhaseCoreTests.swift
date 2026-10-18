import Foundation
import XCTest
@testable import PhaseCore

final class PhaseCoreTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    func testEqualPerformedDatesUseStableCreationAndIDTiesNotUpdatedAt() throws {
        let task = Entry(kind: .task, title: "작업", now: t0)
        let lowID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let highID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        var a = Entry(kind: .done, id: lowID, now: t0)
        a.text = "A"; a.taskID = task.id
        var b = Entry(kind: .done, id: highID, now: t0)
        b.text = "B"; b.taskID = task.id
        var c = Entry(kind: .done, now: t0.addingTimeInterval(1))
        c.text = "C"; c.taskID = task.id; c.date = t0
        var state = PhaseState(entries: [task, b, c, a])
        XCTAssertEqual(state.history(taskID: task.id).map(\.id), [c.id, a.id, b.id])
        try state.editDone(id: b.id, text: "B 수정", notes: "", date: t0, now: t0.addingTimeInterval(500))
        XCTAssertEqual(state.history(taskID: task.id).map(\.id), [c.id, a.id, b.id])
        let reversed = PhaseState(entries: state.entries.reversed())
        XCTAssertEqual(reversed.history(taskID: task.id), state.history(taskID: task.id))
        XCTAssertEqual(reversed.markdown(), state.markdown())
    }

    func testEventSnapshotAndMarkdownStayInOriginalScopeAfterMove() throws {
        let original = Entry(kind: .phase, title: "Original phase", now: t0)
        let destination = Entry(kind: .phase, title: "Destination phase", now: t0)
        var task = Entry(kind: .task, title: "Original title", now: t0)
        task.phaseID = original.id
        var state = PhaseState(entries: [original, destination, task])
        try state.addDone(taskID: task.id, text: "Snapshot performed", date: t0, now: t0)
        try state.endTask(task.id, status: "completed", now: t0)
        task = try XCTUnwrap(state.entry(task.id))
        task.phaseID = destination.id
        task.title = "Destination title"
        try state.upsert(task)
        try state.reopenTask(task.id, now: t0.addingTimeInterval(10))
        XCTAssertEqual(state.phaseHistory(original.id).count, 2)
        XCTAssertEqual(state.phaseHistory(destination.id).map(\.text), ["reopened"])
        XCTAssertEqual(state.items(.event).first?.title, "Original title")
        let export = state.markdown()
        let performed = try XCTUnwrap(export.components(separatedBy: "## 수행 기록\n").last?.components(separatedBy: "## 상태 이력\n").first)
        XCTAssertTrue(performed.contains("국면: Original phase"))
        XCTAssertTrue(performed.contains("Original title"))
        XCTAssertFalse(performed.contains("Destination phase"))
        XCTAssertFalse(performed.contains("Destination title"))
    }

    func testInvalidMutationTimestampRollsBackEveryMutationPath() throws {
        let task = Entry(kind: .task, title: "작업", now: t0)
        var state = PhaseState(entries: [task])
        try state.addDone(taskID: task.id, text: "기존", date: t0, now: t0)
        let done = try XCTUnwrap(state.latestDone(taskID: task.id))
        let invalid = Date(timeIntervalSince1970: .infinity)
        let before = state
        XCTAssertThrowsError(try state.upsert(task, now: invalid))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.toggleSpotlight(task.id, now: invalid))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.reorderTasks([task.id], now: invalid))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.addDone(taskID: task.id, text: "불가", nextStart: "변경 불가", now: invalid))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.editDone(id: done.id, text: "불가", notes: "", date: t0, now: invalid))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.endTask(task.id, status: "completed", now: invalid))
        XCTAssertEqual(state, before)
        try state.toggleSpotlight(task.id, now: t0)
        let starred = state
        XCTAssertThrowsError(try state.reorderSpotlight([task.id], now: invalid))
        XCTAssertEqual(state, starred)
        try state.endTask(task.id, status: "stopped", now: t0)
        let ended = state
        XCTAssertThrowsError(try state.reopenTask(task.id, now: invalid))
        XCTAssertEqual(state, ended)
    }

    func testUpsertNewStarAppendsAndEndedTaskCannotRetainStar() throws {
        var a = Entry(kind: .task, title: "A", now: t0)
        var b = Entry(kind: .task, title: "B", now: t0)
        let c = Entry(kind: .task, title: "C", now: t0)
        var state = PhaseState(entries: [a, b, c])
        try state.toggleSpotlight(c.id)
        a.isSpotlight = true
        try state.upsert(a)
        b.isSpotlight = true
        try state.upsert(b)
        XCTAssertEqual(state.spotlight.map(\.id), [c.id, a.id, b.id])
        a = try XCTUnwrap(state.entry(a.id))
        a.lifecycle = "completed"
        try state.upsert(a)
        XCTAssertFalse(try XCTUnwrap(state.entry(a.id)).isSpotlight)
        XCTAssertEqual(state.spotlight.map(\.id), [c.id, b.id])
    }

    func testUpsertSnapshotCapturesScopeAndCannotRewriteHistoricalPlacement() throws {
        let area = Entry(kind: .area, title: "영역", now: t0)
        var phase = Entry(kind: .phase, title: "옛 국면", now: t0)
        phase.areaID = area.id
        let otherPhase = Entry(kind: .phase, title: "새 국면", now: t0)
        var task = Entry(kind: .task, title: "원래 제목", now: t0)
        task.phaseID = phase.id
        var state = PhaseState(entries: [area, phase, otherPhase, task])
        var record = Entry(kind: .done, now: t0)
        record.taskID = task.id
        record.text = "직접 기록"
        try state.upsert(record, now: t0)
        let captured = try XCTUnwrap(state.entry(record.id))
        XCTAssertEqual(captured.title, "원래 제목")
        XCTAssertEqual(captured.phaseID, phase.id)
        XCTAssertEqual(captured.areaID, area.id)
        task.phaseID = otherPhase.id
        task.title = "바뀐 제목"
        try state.upsert(task)
        var rewritten = captured
        rewritten.phaseID = otherPhase.id
        rewritten.title = "바뀐 제목"
        let before = state
        XCTAssertThrowsError(try state.upsert(rewritten))
        XCTAssertEqual(state, before)
        try state.editDone(id: captured.id, text: "본문만 수정", notes: "", date: t0)
        XCTAssertEqual(state.entry(captured.id)?.phaseID, phase.id)
    }

    func testInvalidDomainValuesRollbackWithoutPartiallyChangingState() throws {
        let task = Entry(kind: .task, title: "유효", now: t0)
        var state = PhaseState(entries: [task])
        var candidates: [Entry] = []
        var invalid = task
        invalid.lifecycle = "unknown"
        candidates.append(invalid)
        invalid = task; invalid.taskKind = "unknown"; candidates.append(invalid)
        invalid = task; invalid.rank = .infinity; candidates.append(invalid)
        invalid = task; invalid.spotlightRank = .nan; candidates.append(invalid)
        invalid = task; invalid.date = Date(timeIntervalSince1970: .infinity); candidates.append(invalid)
        invalid = Entry(kind: .event, now: t0); invalid.text = "unknown"; candidates.append(invalid)
        invalid = Entry(kind: .area, title: "영역", now: t0); invalid.isSpotlight = true; candidates.append(invalid)
        let before = state
        for candidate in candidates {
            XCTAssertThrowsError(try state.upsert(candidate)) { error in
                XCTAssertTrue(error.localizedDescription.contains("."))
            }
            XCTAssertEqual(state, before)
        }
        var wrongReference = task
        wrongReference.phaseID = task.id
        XCTAssertThrowsError(try state.upsert(wrongReference))
        XCTAssertEqual(state, before)
    }

    func testMarkdownExportsAllDurableContentOnceWithReadableCapturedScope() throws {
        var area = Entry(kind: .area, title: "연구 영역", now: t0)
        area.goal = "영역 목표"
        var phase = Entry(kind: .phase, title: "초기 국면", now: t0)
        phase.areaID = area.id
        phase.statusNote = "상황 설명"
        phase.bottleneck = "병목 설명"
        phase.expectedChange = "기대 변화"
        phase.resources = "자료 링크"
        phase.notes = "국면 메모"
        phase.archived = true
        var task = Entry(kind: .task, title: "실험 작업", now: t0)
        task.phaseID = phase.id
        task.areaID = area.id
        task.taskKind = "quick"
        task.goal = "작업 목표"
        task.text = "작업 본문"
        task.notes = "작업 메모"
        task.nextStart = "SECRET_CURRENT_START"
        task.rank = 918273
        task.spotlightRank = 817263
        var inbox = Entry(kind: .inbox, title: "받은 생각", now: t0)
        inbox.text = "분류 전 생각"
        var state = PhaseState(entries: [area, phase, task, inbox])
        try state.addDone(taskID: task.id, text: "UNIQUE_PERFORMED_CONTENT", notes: "수행 메모", nextStart: "SECRET_CURRENT_START", date: t0, now: t0)
        try state.addDone(taskID: nil, text: "독립 수행", date: t0, now: t0)
        try state.endTask(task.id, status: "completed", now: t0)
        try state.reopenTask(task.id, now: t0.addingTimeInterval(1))
        try state.endTask(task.id, status: "stopped", now: t0.addingTimeInterval(2))
        let output = state.markdown()
        for content in ["연구 영역", "영역 목표", "초기 국면", "상황 설명", "병목 설명", "기대 변화", "자료 링크", "국면 메모", "실험 작업", "작업 목표", "작업 본문", "작업 메모", "받은 생각", "분류 전 생각", "수행 메모", "독립 수행", "완료", "중단", "다시 열기", "보관", "빠른 작업"] {
            XCTAssertTrue(output.contains(content), "Missing durable content: \(content)")
        }
        XCTAssertEqual(output.components(separatedBy: "UNIQUE_PERFORMED_CONTENT").count - 1, 1)
        for internalValue in ["SECRET_CURRENT_START", "918273", "817263", "nextStart", "spotlightRank", "completed", "stopped", "reopened", "quick"] + state.entries.map({ $0.id.uuidString }) {
            XCTAssertFalse(output.contains(internalValue), "Leaked internal value: \(internalValue)")
        }
        let performedSection = try XCTUnwrap(output.components(separatedBy: "UNIQUE_PERFORMED_CONTENT").first)
        XCTAssertTrue(performedSection.contains("영역: 연구 영역"))
        XCTAssertTrue(performedSection.contains("국면: 초기 국면"))
        XCTAssertEqual(state.markdown(), output)
    }

    func testDeleteOnlyEphemeralRecordsNeverDeletesTaskOrCurrentStart() throws {
        let task = Entry(kind: .task, title: "보존", now: t0)
        let phase = Entry(kind: .phase, title: "보존 국면", now: t0)
        let area = Entry(kind: .area, title: "보존 영역", now: t0)
        var inbox = Entry(kind: .inbox, now: t0)
        inbox.text = "임시"
        var state = PhaseState(entries: [task, phase, area, inbox])
        try state.addDone(taskID: task.id, text: "기록", nextStart: "유지", date: t0)
        try state.endTask(task.id, status: "completed", now: t0)
        let before = state
        for id in [task.id, phase.id, area.id, UUID()] {
            XCTAssertThrowsError(try state.delete(id))
            XCTAssertEqual(state, before)
        }
        let doneID = try XCTUnwrap(state.items(.done).first?.id)
        let eventID = try XCTUnwrap(state.items(.event).first?.id)
        try state.delete(doneID)
        try state.delete(eventID)
        try state.delete(inbox.id)
        XCTAssertEqual(state.entries.count, 3)
        XCTAssertEqual(state.resume(taskID: task.id), "유지")
        XCTAssertEqual(state.entry(task.id)?.lifecycle, "completed")
    }

    func testArchivingPhaseIsIndependentOfChildTasksAndHistory() throws {
        var phase = Entry(kind: .phase, title: "마친 국면", now: t0)
        var task = Entry(kind: .task, title: "계속하는 작업", now: t0)
        task.phaseID = phase.id
        var state = PhaseState(entries: [phase, task])
        try state.addDone(taskID: task.id, text: "기존 수행", date: t0)
        XCTAssertThrowsError(try state.toggleSpotlight(phase.id))
        try state.toggleSpotlight(task.id)
        let taskBefore = state.entry(task.id)
        let historyBefore = state.phaseHistory(phase.id)
        phase = try XCTUnwrap(state.entry(phase.id))
        phase.archived = true
        try state.upsert(phase)
        XCTAssertFalse(try XCTUnwrap(state.entry(phase.id)).isSpotlight)
        XCTAssertEqual(state.entry(task.id), taskBefore)
        XCTAssertEqual(state.phaseHistory(phase.id), historyBefore)
        XCTAssertEqual(state.spotlight.map(\.id), [task.id])
        XCTAssertTrue(state.items(.event).isEmpty)
        phase.archived = false
        phase.isSpotlight = false
        try state.upsert(phase)
        XCTAssertEqual(state.spotlight.map(\.id), [task.id])
    }

    func testDailyDaysIncludeEventsButHeatmapOnlyIncludesPerformedDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 23)))
        let eventDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 11, hour: 1)))
        let task = Entry(kind: .task, title: "달력", now: t0)
        var state = PhaseState(entries: [task])
        XCTAssertTrue(state.dailyDays(calendar: calendar).isEmpty)
        try state.addDone(taskID: task.id, text: "수행1", date: day)
        try state.addDone(taskID: nil, text: "수행2", date: day.addingTimeInterval(-60))
        try state.endTask(task.id, status: "stopped", now: eventDate)
        XCTAssertEqual(state.dailyDays(calendar: calendar), [calendar.startOfDay(for: eventDate), calendar.startOfDay(for: day)])
        XCTAssertEqual(state.doneDays(calendar: calendar), [calendar.startOfDay(for: day)])
        XCTAssertEqual(state.history(taskID: task.id).count, 1)
        XCTAssertEqual(state.lastPerformed(taskID: task.id), day)
    }

    func testDormancyUsesCalendarMonthNotThirtyDaysAndNeverRecordedIsFalse() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 12)))
        let boundary = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12)))
        let task = Entry(kind: .task, title: "월간", now: t0)
        var state = PhaseState(entries: [task])
        XCTAssertFalse(state.isDormant(taskID: task.id, now: boundary, calendar: calendar))
        try state.addDone(taskID: task.id, text: "수행", date: january, now: january)
        XCTAssertFalse(state.isDormant(taskID: task.id, now: boundary.addingTimeInterval(-1), calendar: calendar))
        XCTAssertTrue(state.isDormant(taskID: task.id, now: boundary, calendar: calendar))
        XCTAssertTrue(state.isDormant(taskID: task.id, now: boundary.addingTimeInterval(1), calendar: calendar))
        XCTAssertFalse(state.isDormant(taskID: task.id, now: january.addingTimeInterval(-1), calendar: calendar))
    }

    func testManualTaskRanksAreIndependentOfSpotlightAndActivity() throws {
        let a = Entry(kind: .task, title: "A", now: t0)
        let b = Entry(kind: .task, title: "B", now: t0.addingTimeInterval(1))
        let c = Entry(kind: .task, title: "C", now: t0.addingTimeInterval(2))
        let phase = Entry(kind: .phase, title: "국면", now: t0)
        var state = PhaseState(entries: [c, a, b, phase])
        try state.toggleSpotlight(a.id)
        try state.toggleSpotlight(c.id)
        try state.reorderTasks([c.id, b.id, a.id], now: t0)
        XCTAssertEqual(state.items(.task).map(\.id), [c.id, b.id, a.id])
        XCTAssertEqual(state.spotlight.map(\.id), [a.id, c.id])
        try state.addDone(taskID: a.id, text: "수행", now: t0.addingTimeInterval(500))
        XCTAssertEqual(state.items(.task).map(\.id), [c.id, b.id, a.id])
        let before = state
        XCTAssertThrowsError(try state.reorderTasks([a.id, a.id]))
        XCTAssertThrowsError(try state.reorderTasks([a.id, phase.id]))
        XCTAssertThrowsError(try state.reorderTasks([UUID()]))
        XCTAssertEqual(state, before)
        try state.reorderTasks([b.id, c.id])
        XCTAssertEqual(state.items(.task).map(\.id), [b.id, c.id, a.id])
    }

    func testEndAndReopenRecordEventsNotDoneAndNeverAutoStar() throws {
        let area = Entry(kind: .area, title: "영역", now: t0)
        var phase = Entry(kind: .phase, title: "국면", now: t0)
        phase.areaID = area.id
        var task = Entry(kind: .task, title: "작업 스냅샷", now: t0)
        task.phaseID = phase.id
        task.nextStart = "현재 시작"
        var state = PhaseState(entries: [area, phase, task])
        try state.toggleSpotlight(task.id)
        try state.endTask(task.id, status: "completed", now: t0)
        XCTAssertEqual(state.entry(task.id)?.lifecycle, "completed")
        XCTAssertEqual(state.resume(taskID: task.id), "현재 시작")
        XCTAssertTrue(state.spotlight.isEmpty)
        XCTAssertTrue(state.items(.done).isEmpty)
        XCTAssertNil(state.lastPerformed(taskID: task.id))
        let event = try XCTUnwrap(state.items(.event).first)
        XCTAssertEqual(event.text, "completed")
        XCTAssertEqual(event.title, "작업 스냅샷")
        XCTAssertEqual(event.phaseID, phase.id)
        XCTAssertEqual(event.areaID, area.id)
        XCTAssertEqual(state.phaseHistory(phase.id), [event])
        XCTAssertEqual(state.areaHistory(area.id), [event])
        let ended = state
        XCTAssertThrowsError(try state.endTask(task.id, status: "completed"))
        XCTAssertThrowsError(try state.toggleSpotlight(task.id))
        XCTAssertEqual(state, ended)
        try state.reopenTask(task.id, now: t0.addingTimeInterval(1))
        XCTAssertEqual(state.entry(task.id)?.lifecycle, "active")
        XCTAssertFalse(try XCTUnwrap(state.entry(task.id)).isSpotlight)
        XCTAssertEqual(state.items(.event).last?.text, "reopened")
        try state.endTask(task.id, status: "stopped", now: t0.addingTimeInterval(2))
        XCTAssertEqual(state.entry(task.id)?.lifecycle, "stopped")
        XCTAssertEqual(state.items(.event).count, 3)
        let before = state
        XCTAssertThrowsError(try state.endTask(task.id, status: "invalid"))
        XCTAssertThrowsError(try state.reopenTask(phase.id))
        XCTAssertEqual(state, before)
    }

    func testTaskOnlySpotlightAppendsReordersAndRejectsPhases() throws {
        let phase = Entry(kind: .phase, title: "국면", now: t0)
        let task = Entry(kind: .task, title: "작업", now: t0)
        let other = Entry(kind: .task, title: "다른 작업", now: t0)
        let area = Entry(kind: .area, title: "영역", now: t0)
        var state = PhaseState(entries: [phase, task, other, area])
        try state.toggleSpotlight(task.id, now: t0)
        XCTAssertThrowsError(try state.toggleSpotlight(phase.id, now: t0))
        try state.toggleSpotlight(other.id, now: t0)
        XCTAssertEqual(state.spotlight.map(\.id), [task.id, other.id])
        try state.reorderSpotlight([other.id, task.id], now: t0)
        XCTAssertEqual(state.spotlight.map(\.id), [other.id, task.id])
        try state.toggleSpotlight(task.id)
        XCTAssertEqual(state.spotlight.map(\.id), [other.id])
        try state.toggleSpotlight(task.id)
        XCTAssertEqual(state.spotlight.map(\.id), [other.id, task.id])
        let before = state
        for bad in [[task.id, task.id], [UUID()], [task.id]] {
            XCTAssertThrowsError(try state.reorderSpotlight(bad))
            XCTAssertEqual(state, before)
        }
        XCTAssertThrowsError(try state.toggleSpotlight(area.id))
        XCTAssertEqual(state, before)
    }

    func testHistoryUsesCapturedPhaseAndAreaAcrossTaskMoves() throws {
        let areaA = Entry(kind: .area, title: "연구", now: t0)
        let areaB = Entry(kind: .area, title: "생활", now: t0)
        var phaseA = Entry(kind: .phase, title: "처음", now: t0)
        phaseA.areaID = areaA.id
        var phaseB = Entry(kind: .phase, title: "나중", now: t0)
        phaseB.areaID = areaB.id
        var task = Entry(kind: .task, title: "옛 제목", now: t0)
        task.phaseID = phaseA.id
        var state = PhaseState(entries: [areaA, areaB, phaseA, phaseB, task])
        try state.addDone(taskID: task.id, text: "이전 수행", date: t0, now: t0)
        let snapshot = try XCTUnwrap(state.latestDone(taskID: task.id))
        XCTAssertEqual(snapshot.areaID, areaA.id)
        task.phaseID = phaseB.id
        task.title = "새 제목"
        try state.upsert(task)
        try state.addDone(taskID: task.id, text: "이후 수행", date: t0.addingTimeInterval(10))
        XCTAssertEqual(state.entry(snapshot.id), snapshot)
        XCTAssertEqual(state.phaseHistory(phaseA.id).map(\.text), ["이전 수행"])
        XCTAssertEqual(state.areaHistory(areaA.id).map(\.text), ["이전 수행"])
        XCTAssertEqual(state.phaseHistory(phaseB.id).map(\.text), ["이후 수행"])
        XCTAssertEqual(state.areaHistory(areaB.id).map(\.text), ["이후 수행"])
        try state.editDone(id: snapshot.id, text: "이전 수행 수정", notes: "", date: t0)
        XCTAssertEqual(state.entry(snapshot.id)?.phaseID, phaseA.id)
        XCTAssertEqual(state.entry(snapshot.id)?.title, "옛 제목")
    }

    func testEditDoneDoesNotBumpPerformedDateOrCurrentStart() throws {
        let task = Entry(kind: .task, title: "작업", now: t0)
        var state = PhaseState(entries: [task])
        try state.addDone(taskID: task.id, text: "첫 수행", nextStart: "다음 시작", date: t0, now: t0)
        let first = try XCTUnwrap(state.latestDone(taskID: task.id))
        let next = t0.addingTimeInterval(100)
        try state.addDone(taskID: task.id, text: "나중 수행", nextStart: "현재 시작", date: next, now: next)
        try state.editDone(id: first.id, text: "첫 수행 수정", notes: "편집 메모", date: t0, now: next.addingTimeInterval(1000))
        XCTAssertEqual(state.lastPerformed(taskID: task.id), next)
        XCTAssertEqual(state.resume(taskID: task.id), "현재 시작")
        XCTAssertEqual(state.entry(first.id)?.date, t0)
        XCTAssertEqual(state.entry(first.id)?.createdAt, t0)
        XCTAssertEqual(state.entry(first.id)?.notes, "편집 메모")
        let before = state
        XCTAssertThrowsError(try state.editDone(id: first.id, text: " ", notes: "", date: next))
        XCTAssertThrowsError(try state.editDone(id: task.id, text: "불가", notes: "", date: next))
        XCTAssertEqual(state, before)
        try state.editDone(id: first.id, text: "날짜 정정", notes: "", date: next.addingTimeInterval(1))
        XCTAssertEqual(state.latestDone(taskID: task.id)?.id, first.id)
    }

    func testRecordingReplacesCurrentStartIncludingBlankAndKeepsPerformedOrder() throws {
        var task = Entry(kind: .task, title: "읽기", now: t0)
        task.nextStart = "오래된 시작"
        var state = PhaseState(entries: [task])
        let performed = t0.addingTimeInterval(100)
        try state.addDone(taskID: task.id, text: "1장", notes: "기록 메모", nextStart: "2장", date: performed, now: t0)
        XCTAssertEqual(state.resume(taskID: task.id), "2장")
        XCTAssertEqual(state.lastPerformed(taskID: task.id), performed)
        XCTAssertEqual(state.latestDone(taskID: task.id)?.notes, "기록 메모")
        try state.addDone(taskID: task.id, text: "과거 보충", nextStart: "", date: t0, now: performed)
        XCTAssertEqual(state.entry(task.id)?.nextStart, "")
        XCTAssertEqual(state.resume(taskID: task.id), "1장")
        XCTAssertEqual(state.history(taskID: task.id).map(\.text), ["1장", "과거 보충"])
        try state.addDone(taskID: nil, text: "독립 기록", date: t0)
        XCTAssertEqual(state.items(.done).count, 3)
        let before = state
        XCTAssertThrowsError(try state.addDone(taskID: task.id, text: " \n ", nextStart: "덮어쓰면 안 됨"))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.addDone(taskID: UUID(), text: "없는 작업"))
        XCTAssertEqual(state, before)
    }

    func testValidatedUpsertIsAtomicAndKeepsCreationDate() throws {
        var state = PhaseState()
        var task = Entry(kind: .task, title: "실험", now: t0)
        try state.upsert(task, now: t0)
        let later = t0.addingTimeInterval(60)
        task.title = "수정"
        task.createdAt = later
        try state.upsert(task, now: later)
        XCTAssertEqual(state.entry(task.id)?.createdAt, t0)
        XCTAssertEqual(state.entry(task.id)?.updatedAt, later)
        for kind in [EntryKind.area, .phase, .task, .done, .inbox] {
            let before = state
            XCTAssertThrowsError(try state.upsert(Entry(kind: kind, title: " \n ", now: t0))) {
                XCTAssertFalse($0.localizedDescription.isEmpty)
            }
            XCTAssertEqual(state, before)
        }
        task.phaseID = UUID()
        let before = state
        XCTAssertThrowsError(try state.upsert(task))
        XCTAssertEqual(state, before)
        var inbox = Entry(kind: .inbox, now: t0)
        inbox.text = "생각"
        try state.upsert(inbox)
        XCTAssertEqual(state.items(.inbox).count, 1)
    }

    func testEntryDefaultsAndCodableRoundTrip() throws {
        let entry = Entry(kind: .task, title: "읽기", now: t0)
        XCTAssertEqual(entry.title, "읽기")
        XCTAssertEqual(entry.date, t0)
        XCTAssertEqual(entry.createdAt, t0)
        XCTAssertEqual(entry.updatedAt, t0)
        XCTAssertEqual(entry.taskKind, "general")
        XCTAssertEqual(entry.lifecycle, "active")
        XCTAssertEqual(entry.nextStart, "")
        XCTAssertFalse(entry.isSpotlight)
        XCTAssertFalse(entry.archived)
        XCTAssertNil(entry.phaseID)
        let state = PhaseState(entries: [entry])
        XCTAssertEqual(try JSONDecoder().decode(PhaseState.self, from: JSONEncoder().encode(state)), state)
        XCTAssertEqual(state.entry(entry.id), entry)
        XCTAssertEqual(state.items(.task), [entry])
        XCTAssertEqual(EntryKind.allCases.count, 6)
    }
}
