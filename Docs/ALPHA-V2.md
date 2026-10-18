# 알파 v2 구현 계약과 결정

현재 단계는 상호작용/배치 알파입니다. 카드 색상·타이포그래피·디테일 디자인의 최종화는 베타 범위입니다. 아래는 구현 위치와 의도이며 런타임 합격표가 아닙니다. Mac 인수는 `Tests/UIAcceptance.md`를 사용합니다.

| 결정 | 구현 | 이유 / 경계 |
|---|---|---|
| 1. Phases / Areas 상단 전환 | `PhaseViews.swift`의 `PhasesView`, AppStorage | Area를 숨기거나 별도 하단 탭으로 늘리지 않음 |
| 2. Task 카드 목적지는 Task 하나 | `EntryLink`, `TaskListRow`, `TaskDetailView` | Phase 이동은 상세의 명시적 버튼. 별 ON/OFF는 별도 명시 조작 |
| 3. 입력 중 Phase 읽기 전용 참고 | `PhaseReferenceSheet`, `ClassificationDetailView(readOnly:)` | 위 sheet만 닫아 같은 draft 유지. 관리·Task 생성·기록 편집 경로 없음. Phase 편집에는 Inbox 참고 |
| 4. Spotlight 왼쪽 스와이프 OFF | `SpotlightView.remove`, `undoRemoval` | 원본·이력 보존, 확인창 없이 제거하고 직전 제거만 Undo |
| 5. 선택+재정렬 | `List(selection:)`, `.tag`, `.onMove`, iOS EditButton | native 선택/핸들 사용. 사용자 한 손가락 drag 제스처는 추가하지 않음. 두 손가락 지원/동시 핸들은 기기 미확인 |
| 6. Spotlight 표시 | Area / Phase + 제목 + 유형 + 비어 있지 않은 재개 2줄 | General/Quick 임시 다른 배경, 새 별은 아래. sync 문구는 safeAreaInset 보조 영역 |
| 7–8. Task 필터 | 복수 Area(미소속), 유형, AppStorage, 숨긴 패널·활성 표시·Clear all | Spotlight 필터와 불필요한 검색 제거. 필터 상태는 기기 로컬 |
| 9B. 기본/날짜 정렬 | `TasksView` | 기본 Area / Phase 이름순, 그룹 내 createdAt 최신순. 날짜 모드는 헤더 없는 생성 최신/오래된순 |
| 10. 종료 작업 분리 | `EndedTasksView` | 종료 사건 시각 최신순, 완료/중단 필터·badge. 별 토글 없음, 상세에서 이력/재개 |
| 11–12. 상세 맥락/자료 | `TaskDetailView` | 재개 위, 중복 최신수행 섹션 없음, 내용 있는 설명/자료만 펼쳐 표시 |
| 13. 이력 5개씩 | `MoreControls`, `RecordRow` | View all은 왼쪽 inline, More +5, Collapse 5. trailing swipe 아이콘·삭제 확인, 즉시삭제 full-swipe 금지. 자기 Task 중복 링크 없음 |
| 14. 종료와 마지막 Done | `endTask(finalDone:)`, `recordTimeline`, `lifecycleLabel` | 선택 본문은 실제 Done, 빈칸은 사건만. 값 상태 후보를 검증한 후 한 번 교체. UI만 결합, 원본 사건/기록·Markdown은 보존 |
| 15. Phase 상태·생성 picker | `phaseStatus`, `setPhaseStatus`, `EntryEditor` | Active/Completed/Stopped. 신규 선택은 active만, 기존 선택 종료 Phase는 보존. Area 머리글·Phase 제목, 생성 Task에 nextStart 없음 |
| 16B–17. Area 상세 | `ClassificationDetailView` | 모든 Phase·상태 Task 혼합, 생성 최신순·5개+펼침. 활성 Phase 기본, 과거는 완료/중단 함께 |
| 18. 주/월 캘린더 | `DailyLogView` | Week 초기/모드 기억, 모드 전환은 selectedDate 변경 없음. 주간 전체 기록·날짜 스크롤, 월간 전체 달력·선택일. 잔디/위젯 없음 |
| 19. Area · N days | `performedAreaDays` | 캡처된 areaID별 서로 다른 Done 날짜. [주 시작, 다음 주 시작) 반개구간. 사건·수정시각·Task 생성으로 수행을 추론하지 않음 |
| 20. 빈 선택일 | `DailyLogView` | No records 한 줄, 별도 유도문구/빈 Task 영역 없음 |

## 관리와 export

Task의 편집/이동/유형 변경은 상단 메뉴의 `Edit`로 같은 편집기를 엽니다. 별/완료/중단/재개도 같은 메뉴에 있고 아래 관리 섹션은 없습니다. Phases 글로벌 카드에 Area 목록을 덧붙이지 않으며 Area는 작은 정보입니다. 전체 Markdown export는 Phases의 공유 메뉴에 남깁니다. 선택 국면 export나 import는 만들지 않습니다. Daily Log의 독립 Done은 상단 아이콘 하나로 엽니다.

## 저장 호환성

- SwiftData `RevisionEntity`와 CloudKit 컨테이너/서명 설정은 그대로입니다. Entry는 기존처럼 JSON payload로 저장되므로 새 SwiftData schema는 필요하지 않습니다.
- Phase 상태는 기존 `lifecycle` 문자열과 `archived` Bool을 사용합니다. 기존 archived=true/lifecycle=active는 읽기 전용 해석에서 completed입니다. 조회로 저장소를 바꾸지 않습니다. 명시적인 상태 저장은 lifecycle과 archived를 일치시킵니다. Task의 수명주기/별/이력은 변경하지 않습니다.
- 마지막 Done과 사건의 연결은 event의 선택적 `linkedDoneID: UUID?`입니다. 이전 payload에 키가 없으면 nil이며 합성 Codable의 decodeIfPresent로 읽힙니다. 기존 필수 필드를 없애거나 이름을 바꾸지 않았습니다.
- 화면 통합은 연결된 Done이 존재하고 날짜도 같을 때만 사건 행을 숨깁니다. Done이 삭제되거나 날짜가 정정되면 원래 사건 행이 다시 표시됩니다. 사건 자체의 날짜/종류는 바뀌지 않습니다. 현재 재개 힌트의 역사적 포인터로 사용하지 않습니다.
- 예전 앱과 신버전을 동시에 편집하면 구버전이 모르는 선택 필드를 다시 저장할 때 연결 정보가 사라질 수 있습니다. 원본 Done·사건은 남지만 UI 결합이 풀릴 수 있으므로 테스트 기기는 같은 v2로 맞춥니다. 전체 항목 LWW와 기기 시계 차이의 기존 제약도 그대로입니다.
- 필터/정렬/모드 UserDefaults는 개인 기기의 UI 상태이며 CloudKit revision과 별도입니다. 탭/상세를 오가도 유지합니다. 캘린더 선택일은 해당 뷰 세션에서 유지하고 모드 전환만으로는 바뀌지 않습니다.

## 범위 밖과 정직한 한계

실제 SDK 타입 검사와 UI 런타임은 Linux에서 실행하지 못했습니다. 특히 SwiftUI List의 iOS 두 손가락 선택과 선택 원+핸들 공존, Mac 드래그/다중선택, sheet 위 sheet의 draft 유지, picker header 및 주간 스크롤은 Mac/기기 확인이 필요합니다. native 지원을 흉내 낸 custom drag를 넣거나 검증되었다고 표시하지 않았습니다. 실패 저장·Cloud 수신·큰 글자·접근성·데이터 대량 증가도 별도 인수 대상입니다. 자동 이월/할당량/학습 코칭/스트릭/자동 NLP는 추가하지 않았습니다.
