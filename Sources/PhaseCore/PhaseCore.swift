import Foundation

public enum EntryKind: String, Codable, CaseIterable, Sendable {
    case area, phase, task, done, event, inbox
}

public struct Entry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: EntryKind
    public var title: String
    public var text = ""
    public var goal = ""
    public var statusNote = ""
    public var bottleneck = ""
    public var expectedChange = ""
    public var resources = ""
    public var notes = ""
    public var nextStart = ""
    public var areaID: UUID?
    public var phaseID: UUID?
    public var taskID: UUID?
    /// Optional on lifecycle events; old JSON payloads decode without this key.
    public var linkedDoneID: UUID?
    public var date: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var rank: Double = 0
    public var spotlightRank: Double = 0
    public var isSpotlight = false
    public var archived = false
    public var taskKind = "general"
    public var lifecycle = "active"

    public init(kind: EntryKind, title: String = "", id: UUID = UUID(), now: Date = Date()) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = now
        self.createdAt = now
        self.updatedAt = now
    }
}

public struct AreaPerformedDays: Equatable, Identifiable, Sendable {
    public var areaID: UUID?
    public var title: String
    public var days: Int
    public var id: String { areaID?.uuidString ?? "unassigned" }
}

public struct PhaseState: Codable, Equatable, Sendable {
    public var entries: [Entry]
    public init(entries: [Entry] = []) { self.entries = entries }
    public func entry(_ id: UUID) -> Entry? { entries.first { $0.id == id } }
    public func items(_ kind: EntryKind) -> [Entry] {
        let values = entries.filter { $0.kind == kind }
        if [.done, .event].contains(kind) { return values }
        return values.sorted { a, b in a.rank == b.rank ? Self.stableOrder(a, b) : a.rank < b.rank }
    }

    /// Legacy archived phases read as completed without rewriting stored revisions.
    public func phaseStatus(_ phase: Entry) -> String {
        phase.lifecycle == "active" && phase.archived ? "completed" : phase.lifecycle
    }

    public mutating func setPhaseStatus(_ id: UUID, status: String, now: Date = Date()) throws {
        guard ["active", "completed", "stopped"].contains(status) else {
            throw PhaseError.invalid("국면 상태를 확인해 주세요.")
        }
        var phase = try require(id, kind: .phase)
        phase.lifecycle = status
        phase.archived = status != "active"
        try upsert(phase, now: now)
    }

    public func currentTasks() -> [Entry] {
        items(.task).filter { $0.lifecycle == "active" }
    }

    /// A filtered list may be reordered without moving tasks outside that list.
    public mutating func reorderTasks(_ ids: [UUID], now: Date = Date()) throws {
        try Self.validateTimestamp(now)
        guard Set(ids).count == ids.count, ids.allSatisfy({ entry($0)?.kind == .task }) else {
            throw PhaseError.invalid("작업 순서 목록을 확인해 주세요.")
        }
        let selected = Set(ids)
        var iterator = ids.makeIterator()
        let order = items(.task).map { selected.contains($0.id) ? iterator.next()! : $0.id }
        for (rank, id) in order.enumerated() {
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].rank = Double(rank)
                if selected.contains(id) { entries[index].updatedAt = now }
            }
        }
    }

    public mutating func delete(_ id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { throw PhaseError.invalid("삭제할 항목을 찾을 수 없습니다.") }
        guard [.inbox, .done, .event].contains(entries[index].kind) else { throw PhaseError.invalid("작업·국면·영역은 삭제하지 않고 보관해 주세요.") }
        entries.remove(at: index)
    }

    public mutating func upsert(_ entry: Entry, now: Date = Date()) throws {
        try Self.validateTimestamp(now)
        var value = entry
        if value.isSpotlight, value.kind != .task {
            throw PhaseError.invalid("작업만 스포트라이트에 올릴 수 있습니다.")
        }
        let existing = self.entry(value.id)
        if [.done, .event].contains(value.kind) {
            if let old = existing {
                guard value.taskID == old.taskID, value.phaseID == old.phaseID,
                      value.areaID == old.areaID, value.title == old.title else {
                    throw PhaseError.invalid("기록 당시의 작업과 소속은 변경할 수 없습니다.")
                }
            } else if let id = value.taskID {
                let task = try require(id, kind: .task)
                value.title = task.title
                value.phaseID = task.phaseID
                value.areaID = task.areaID ?? task.phaseID.flatMap { self.entry($0)?.areaID }
            }
        }
        if value.archived || (value.kind == .task && value.lifecycle != "active") { value.isSpotlight = false }
        if value.isSpotlight, existing?.isSpotlight != true {
            value.spotlightRank = (spotlight.map(\.spotlightRank).max() ?? -1) + 1
        }
        try validate(value)
        if let index = entries.firstIndex(where: { $0.id == value.id }) {
            guard entries[index].kind == value.kind else { throw PhaseError.invalid("항목 종류를 바꿀 수 없습니다.") }
            value.createdAt = entries[index].createdAt
            value.updatedAt = now
            entries[index] = value
        } else {
            value.updatedAt = now
            entries.append(value)
        }
    }

    public var spotlight: [Entry] {
        entries.filter { $0.isSpotlight && !$0.archived && $0.kind == .task && $0.lifecycle == "active" }
            .sorted { a, b in a.spotlightRank == b.spotlightRank ? Self.stableOrder(a, b) : a.spotlightRank < b.spotlightRank }
    }

    public mutating func toggleSpotlight(_ id: UUID, now: Date = Date()) throws {
        try Self.validateTimestamp(now)
        guard let index = entries.firstIndex(where: { $0.id == id }), entries[index].kind == .task else {
            throw PhaseError.invalid("작업만 스포트라이트에 올릴 수 있습니다.")
        }
        if !entries[index].isSpotlight {
            guard !entries[index].archived, entries[index].kind != .task || entries[index].lifecycle == "active" else {
                throw PhaseError.invalid("진행 중인 항목만 스포트라이트에 올릴 수 있습니다.")
            }
            entries[index].spotlightRank = (spotlight.map(\.spotlightRank).max() ?? -1) + 1
        }
        entries[index].isSpotlight.toggle()
        entries[index].updatedAt = now
    }

    public mutating func reorderSpotlight(_ ids: [UUID], now: Date = Date()) throws {
        try Self.validateTimestamp(now)
        guard ids.count == Set(ids).count, Set(ids) == Set(spotlight.map(\.id)) else {
            throw PhaseError.invalid("스포트라이트 순서 목록을 확인해 주세요.")
        }
        for (rank, id) in ids.enumerated() {
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].spotlightRank = Double(rank)
                entries[index].updatedAt = now
            }
        }
    }

    private static func stableOrder(_ a: Entry, _ b: Entry) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.id.uuidString < b.id.uuidString
    }

    public func history(taskID: UUID) -> [Entry] {
        entries.filter { $0.kind == .done && $0.taskID == taskID }.sorted(by: Self.historyOrder)
    }
    public func areaHistory(_ id: UUID) -> [Entry] {
        entries.filter { [.done, .event].contains($0.kind) && $0.areaID == id }.sorted(by: Self.historyOrder)
    }
    public func phaseHistory(_ id: UUID) -> [Entry] {
        entries.filter { [.done, .event].contains($0.kind) && $0.phaseID == id }.sorted(by: Self.historyOrder)
    }
    public func latestDone(taskID: UUID) -> Entry? { history(taskID: taskID).first }
    public func lifecycleLabel(for done: Entry) -> String? {
        entries.first { $0.kind == .event && $0.linkedDoneID == done.id }?.text
    }

    /// Combine a final Done and its lifecycle event for presentation only.
    /// If the Done was deleted or its date corrected, retain the event row.
    public func recordTimeline() -> [Entry] {
        entries.filter { record in
            guard [.done, .event].contains(record.kind) else { return false }
            if record.kind == .event, let id = record.linkedDoneID,
               let done = entry(id), done.kind == .done, done.date == record.date { return false }
            return true
        }.sorted(by: Self.historyOrder)
    }
    public func lastPerformed(taskID: UUID) -> Date? { latestDone(taskID: taskID)?.date }
    public func dailyDays(calendar: Calendar = .current) -> [Date] {
        Set(entries.filter { [.done, .event].contains($0.kind) }.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
    }
    public func doneDays(calendar: Calendar = .current) -> Set<Date> {
        Set(items(.done).map { calendar.startOfDay(for: $0.date) })
    }

    public func performedAreaDays(in interval: DateInterval, calendar: Calendar = .current) -> [AreaPerformedDays] {
        let records = items(.done).filter { $0.date >= interval.start && $0.date < interval.end }
        let groups = Dictionary(grouping: records, by: \.areaID)
        return groups.map { id, values in
            AreaPerformedDays(areaID: id, title: id.flatMap { entry($0)?.title } ?? "Unassigned",
                              days: Set(values.map { calendar.startOfDay(for: $0.date) }).count)
        }.sorted { $0.title == $1.title ? $0.id < $1.id : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func isDormant(taskID: UUID, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let performed = lastPerformed(taskID: taskID),
              let boundary = calendar.date(byAdding: .month, value: 1, to: performed) else { return false }
        return now >= boundary
    }

    public func resume(taskID: UUID) -> String {
        if let start = entry(taskID)?.nextStart, !start.isBlank { return start }
        return latestDone(taskID: taskID)?.text ?? ""
    }

    public mutating func addDone(taskID: UUID?, text: String, notes: String = "", nextStart: String = "", date: Date = Date(), now: Date = Date()) throws {
        var done = Entry(kind: .done, now: now)
        done.text = text
        done.notes = notes
        done.date = date
        if let id = taskID {
            let task = try require(id, kind: .task)
            done.taskID = id
            done.title = task.title
            done.areaID = task.areaID ?? task.phaseID.flatMap { entry($0)?.areaID }
            done.phaseID = task.phaseID
        }
        try validate(done)
        // Validate everything before touching either the record or the current start.
        entries.append(done)
        if let id = taskID, let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].nextStart = nextStart
            entries[index].updatedAt = now
        }
    }

    public mutating func endTask(_ id: UUID, status: String, finalDone: String = "", now: Date = Date()) throws {
        guard ["completed", "stopped"].contains(status) else { throw PhaseError.invalid("완료 또는 중단을 선택해 주세요.") }
        let task = try require(id, kind: .task)
        guard task.lifecycle == "active" else { throw PhaseError.invalid("이미 종료된 작업입니다.") }
        var candidate = self
        var doneID: UUID?
        if !finalDone.isBlank {
            try candidate.addDone(taskID: id, text: finalDone, date: now, now: now)
            doneID = candidate.entries.last?.id
        }
        try candidate.transition(candidate.entry(id)!, lifecycle: status, event: status, now: now)
        if let index = candidate.entries.indices.last { candidate.entries[index].linkedDoneID = doneID }
        self = candidate
    }

    public mutating func reopenTask(_ id: UUID, now: Date = Date()) throws {
        let task = try require(id, kind: .task)
        guard ["completed", "stopped"].contains(task.lifecycle) else { throw PhaseError.invalid("종료된 작업만 다시 열 수 있습니다.") }
        try transition(task, lifecycle: "active", event: "reopened", now: now)
    }

    private mutating func transition(_ task: Entry, lifecycle: String, event: String, now: Date) throws {
        var changed = task
        changed.lifecycle = lifecycle
        changed.isSpotlight = false
        changed.updatedAt = now
        var record = Entry(kind: .event, title: task.title, now: now)
        record.text = event
        record.taskID = task.id
        record.phaseID = task.phaseID
        record.areaID = task.areaID ?? task.phaseID.flatMap { entry($0)?.areaID }
        try validate(changed)
        try validate(record)
        if let index = entries.firstIndex(where: { $0.id == task.id }) { entries[index] = changed }
        entries.append(record)
    }

    public mutating func editDone(id: UUID, text: String, notes: String, date: Date, now: Date = Date()) throws {
        var done = try require(id, kind: .done)
        done.text = text
        done.notes = notes
        done.date = date
        try upsert(done, now: now)
    }

    private func require(_ id: UUID, kind: EntryKind) throws -> Entry {
        guard let value = entry(id), value.kind == kind else { throw PhaseError.invalid("항목을 찾을 수 없습니다.") }
        return value
    }

    private static func historyOrder(_ a: Entry, _ b: Entry) -> Bool {
        if a.date != b.date { return a.date > b.date }
        if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        return a.id.uuidString < b.id.uuidString
    }

    private static func validateTimestamp(_ date: Date) throws {
        guard date.timeIntervalSince1970.isFinite else { throw PhaseError.invalid("날짜가 올바르지 않습니다.") }
    }

    private func validate(_ value: Entry) throws {
        guard value.rank.isFinite, value.spotlightRank.isFinite,
              [value.date, value.createdAt, value.updatedAt].allSatisfy({ $0.timeIntervalSince1970.isFinite }) else {
            throw PhaseError.invalid("날짜와 순서 값이 올바르지 않습니다.")
        }
        if value.kind == .task {
            guard ["general", "quick"].contains(value.taskKind), ["active", "completed", "stopped"].contains(value.lifecycle) else {
                throw PhaseError.invalid("작업 유형 또는 상태가 올바르지 않습니다.")
            }
        }
        if value.kind == .event, !["completed", "stopped", "reopened"].contains(value.text) {
            throw PhaseError.invalid("상태 이력 값이 올바르지 않습니다.")
        }
        if value.isSpotlight, value.kind != .task {
            throw PhaseError.invalid("작업만 스포트라이트에 올릴 수 있습니다.")
        }
        if [.area, .phase, .task].contains(value.kind), value.title.isBlank {
            throw PhaseError.invalid("제목을 입력해 주세요.")
        }
        if [.done, .inbox].contains(value.kind), value.text.isBlank {
            throw PhaseError.invalid("내용을 입력해 주세요.")
        }
        for (id, kind) in [(value.areaID, EntryKind.area), (value.phaseID, .phase), (value.taskID, .task)] {
            if let id = id, entry(id)?.kind != kind { throw PhaseError.invalid("연결된 항목을 찾을 수 없습니다.") }
        }
    }
}

public enum PhaseError: LocalizedError, Equatable, Sendable {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
