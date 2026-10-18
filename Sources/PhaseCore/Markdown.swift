import Foundation

extension PhaseState {
    /// A durable, human-readable export. History is emitted once, using captured
    /// references rather than the task's current placement. Runtime ranks and
    /// the replaceable current-start hint intentionally never leave the app.
    public func markdown() -> String {
        var output = ["# Phase System", ""]
        let sections: [(EntryKind, String)] = [
            (.area, "영역"), (.phase, "국면"), (.task, "작업"),
            (.inbox, "인박스"), (.done, "수행 기록"), (.event, "상태 이력")
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for (kind, heading) in sections {
            output += ["## \(heading)", ""]
            let values = kind == .done || kind == .event
                ? items(kind).sorted(by: exportHistoryOrder) : items(kind)
            if values.isEmpty { output += ["없음", ""]; continue }
            for value in values {
                let title = value.title.isEmpty ? (kind == .done ? "독립 수행" : heading) : value.title
                output += ["### \(title)", ""]
                if kind == .done || kind == .event {
                    output += ["날짜: \(formatter.string(from: value.date))", ""]
                }
                if let id = value.areaID, let area = entry(id) { output += ["영역: \(area.title)", ""] }
                if let id = value.phaseID, let phase = entry(id) { output += ["국면: \(phase.title)", ""] }
                if value.taskID != nil { output += ["작업: \(value.title)", ""] }
                if value.archived { output += ["상태: 보관", ""] }
                if kind == .task {
                    output += ["유형: \(value.taskKind == "quick" ? "빠른 작업" : "일반 작업")", "상태: \(readableStatus(value.lifecycle))", ""]
                }
                if kind == .event {
                    output += ["변경: \(readableStatus(value.text))", ""]
                } else if !value.text.isEmpty {
                    output += [value.text, ""]
                }
                let fields = [
                    ("목표", value.goal), ("현재 상황", value.statusNote),
                    ("병목", value.bottleneck), ("기대 변화", value.expectedChange),
                    ("자료", value.resources), ("메모", value.notes)
                ]
                for (label, content) in fields where !content.isEmpty {
                    output += ["**\(label)**", "", content, ""]
                }
            }
        }
        return output.joined(separator: "\n")
    }
}

private func readableStatus(_ value: String) -> String {
    switch value {
    case "completed": return "완료"
    case "stopped": return "중단"
    case "reopened": return "다시 열기"
    default: return "진행 중"
    }
}

private func exportHistoryOrder(_ a: Entry, _ b: Entry) -> Bool {
    if a.date != b.date { return a.date > b.date }
    if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
    return a.id.uuidString < b.id.uuidString
}
