# 알파 v2 수동 UI 인수 — Mac / iPhone / iPad

## 실행 경계

**아래 항목은 모두 미실행 체크리스트입니다.** Linux의 Python gate·Swift 문법 파싱은 화면 실행, SDK 타입 검사, 제스처, 접근성 또는 저장 검증이 아닙니다. 이전 알파의 사용자 시뮬레이터 성공을 v2 합격으로 대신하지 않습니다.

먼저 `PhaseSystem.xcodeproj` → **PhaseSystem** / iPhone 시뮬레이터, **PhaseSystemMac** / My Mac으로 빌드·Run합니다. SwiftUI 타입 오류가 있으면 해당 빌드 로그를 먼저 보존합니다. iPad wide/compact와 실제 터치 기기도 확인합니다. 서명/Cloud는 README, 세 기기 전파는 `Docs/DEVICE-TESTS.md`를 따릅니다. 실제 사용자 기록 대신 테스트 자료를 사용하고 기존 앱/저장소 삭제로 해결하지 않습니다.

## 준비 자료

- Area 두 개(A, B), 미소속 Phase, 같은 이름이지만 서로 다른 Area의 Phase, 활성/완료/중단/이전 archived Phase.
- General/Quick 각각 소속/미소속 Task, 종료 Phase 안의 활성 Task, 완료/중단 Task.
- 생성일·수행일·종료일이 서로 다른 Task. 기록 12개인 Task와 작업 12개인 Area.
- 같은 날짜 같은 Area에 Done 두 개, 다른 날짜 같은 Area에 Done, 독립 Done, 사건만 있는 날짜, 아무 기록 없는 날짜.

## 인수 항목 (각 항목 기기/결과/로그 기록)

1. [ ] **Phases / Areas**: 상단 segmented 전환으로 발견 가능. Area 하단 탭/글로벌 Phase 아래 별도 Area 목록 없음. 다른 탭으로 갔다 돌아와도 모드 기억. Phase 카드 Area 정보 어디를 눌러도 Phase 하나로 이동.
2. [ ] **Task 목적지**: 카드 제목/유형/여백은 Task 상세. Phase/Area로 나뉘는 숨은 클릭 영역 없음. Tasks 별 ON/OFF만 명시적으로 상태 변경하고 탐색하지 않음. 상세 제목 아래 Area / Phase 버튼은 Phase 상세로 이동.
3. [ ] **입력 중 참고**: Task/Done 편집에 미저장 제목·본문·날짜·메모를 입력 → Phase reference → 읽기 전용 맥락 확인 → Close. 입력값과 원래 편집 화면 유지. 참조에는 편집/완료/Task 생성/기록 삭제 경로 없음. Phase 편집의 Inbox reference도 읽기 전용·초안 유지. 참고 동작만으로 저장 revision이 생기지 않음.
4. [ ] **Spotlight 단일 제거**: 왼쪽 스와이프(오른쪽 trailing action 노출)로 OFF. 확인창 없이 제거, Task·기록은 유지. Undo로 이전 위치 복구. 삭제가 아닌 별 제거임을 확인. Undo 전 다른 Task 추가/종료가 있어도 유효 Task만 복구하고 새 항목은 잃지 않음.
5. [ ] **Spotlight 편집**: iOS Edit에서 선택 원+재정렬 핸들 동시 표시. 두 개 선택해 한 번에 제거, Undo. 핸들 drag로 순서 변경 후 앱 재시작해 유지. 일반 drag와 다중선택 충돌 없음. native 두 손가락 swipe 선택은 지원 여부를 실제로 기록(미지원이면 미지원으로 남기고 합격 주장 금지). Mac은 기본 modifier 다중선택/drag 확인. Move up/down 컨텍스트 메뉴 없음.
6. [ ] **Spotlight 표시**: Phase/Area는 들어가지 않음. Area / Phase 작은 글씨·제목·유형·재개 최대 2줄. 빈 재개 placeholder 없음. General/Quick 배경이 절제되어 구분되며 큰 글자/다크모드 대비 확인. 새 별 맨 아래, sync 문구는 목록 항목이 아님.
7. [ ] **Task 필터**: 처음 패널 숨김. 버튼으로 복수 Area와 Unassigned·All/General/Quick 선택. AND 조건 정확, Spotlight 필터 없음. 미소속은 Area가 없는 Phase 포함. 종료 Phase의 활성 Task가 여전히 보임.
8. [ ] **상태 기억**: 필터/정렬 선택 → 상세/다른 탭/넓은 split 화면 전환 → 돌아와도 유지. 활성 표시와 Clear all 동작. 필터/모드만 바꿔 도메인 저장/Cloud 이력 쓰기가 발생하지 않음.
9. [ ] **9B 정렬**: 기본 Area / Phase 이름순 그룹 헤더는 카드 밖. 같은 이름의 Phase가 다른 Area/ID에서 합쳐지지 않음. 그룹 내부는 생성 최신순. 생성 최신/오래된순 선택은 그룹 없는 순수 생성일 정렬이며 마지막 Done/수정일 영향 없음. 카드 제목 옆 중복 별 없음.
10. [ ] **종료 작업**: Tasks 맨 위 Ended tasks로 별도 이동. 현재 목록에 종료 Task 없음. 종료 목록은 종료 사건 최신순 평면, Completed/Stopped badge·유형 필터. 별 버튼 없음. 상세 이력/재개 가능, 재개해도 별 자동 복구 안 함.
11. [ ] **재개 힌트**: 기존 힌트가 있는 Task에 새 Done을 빈 힌트로 저장 → 이전 힌트 제거·수행일 기준 최신 Done 본문 표시. 새 힌트를 넣으면 그것으로 교체. 과거 Done 본문 수정/삭제는 현재 힌트 불변. 최신 항목도 History에 보이지만 별도 Latest performed 섹션은 없음.
12. [ ] **내용 섹션**: 설명/자료가 있으면 펼쳐 표시, 없으면 빈 섹션/No resources/No starting point 없음. HTTP(S) 링크만 안전하게 별도 열기. 긴 여러 줄/큰 글자 확인.
13. [ ] **페이지/행 동작**: Task 이력 12개 → 5개 → More 10개 → View all 12개(같은 화면) → Collapse 5개. View all/Collapse는 왼쪽. Area 작업·분류 이력·Area Phase 명시적 목록도 같은 패턴. Done trailing swipe는 편집/삭제 아이콘, full-swipe 즉시삭제 불가·삭제 확인. Mac 컨텍스트 메뉴도 확인. Task 상세 이력에는 자기 Task 이동 버튼/링크 없음. 사건 행은 편집·삭제 불가.
14. [ ] **종료 확인**: Complete/Stop → 최종 Done 빈칸 확인은 사건만 생성·수행일 점 없음. 본문 입력 후 확인은 실제 Done+사건 생성, UI에서는 하나의 완료/중단 Done 행. 최종 Done 편집 가능, 날짜 정정 시 원래 사건 날짜는 유지. Done 삭제 후에도 사건은 남음. Done 저장만으로 Task가 자동 종료되지 않음.
15. [ ] **Phase 수명주기/Task 생성**: Active/Completed/Stopped 구분·과거 탐색. Phase 종료해도 자식 Task 종료/이동/별 변경 없음. 이전 archived Phase는 Completed로 보이고 읽기만으로 데이터 쓰지 않음. 신규 Task picker는 Area 머리글+Phase 제목, 종료 Phase 제외. 기존 종료 Phase 소속 Task 편집 시 현재 값이 정확히 보임. Phase에서 Add Task는 수정 가능한 미리선택, Tasks에서 Add Task는 Unassigned. 신규 Task에 next-start 필드 없음, Done에는 선택 입력 유지.
16. [ ] **16B Area 상세**: 모든 Phase와 active/completed/stopped Task를 혼합해 생성 최신순, badge와 5개+More/View all/Collapse. 기본 활성 Phase 목록, Show past phases로 과거 포함. Task 이동 뒤 현재 소속은 바뀌나 수행 이력 소속은 옛 Area 유지.
17. [ ] **과거 Phase**: completed와 stopped가 같은 past 범위에 함께 포함. 상태가 서로 구별되며 내부용 phase-archive 문구 없음.
18. [ ] **Daily 주/월**: 처음 Week, 마지막 모드 기억. 접힘 없는 가로 주간/월 전체 grid. 주/월 이전·다음 이동과 월 경계/윤년/로컬 firstWeekday 확인. 모드 전환은 선택일 유지. 월은 선택일 기록, 주는 주 전체 기록을 날짜순 세로 표시. 주간 날짜 탭은 그 날짜로 스크롤(빈 선택일도 meaningful 표시), 다른 날 기록을 숨기지 않음. 별도 dates-with-records 목록/잔디/위젯 없음.
19. [ ] **고유 수행일**: 같은 Area 같은 날 Done 두 개는 1 day, 다른 날 추가하면 2 days. 다른 Area 같은 날은 해당 Area별 1. 독립 Done은 Unassigned. 종료/재개 사건만 있는 날은 집계·점 제외. 주 시작 포함/다음 주 시작 제외, 자정·DST·날짜 정정·삭제 후 갱신 확인. 횟수·시간·강도·근면도를 추론하지 않음.
20. [ ] **빈 날짜**: 선택일이 비었으면 No records 한 줄만. 임의 날짜의 기록으로 자동 선택 대체하지 않음. 주간의 다른 날 실제 기록은 계속 남음.

## 공통 회귀

- [ ] Task 관리(Edit·소속/유형 변경·별·완료·중단·재개)는 상단 overflow. 이력 아래 관리 섹션 없음. Edit 라벨은 Edit.
- [ ] +는 글자 없는 아이콘, 탭 캡처/0.5초 hold 목록이 동시에 발동하지 않음. 접근성 기본 캡처와 Open Inbox 동작. 모든 탭·상세에서 저장/취소 후 같은 경로.
- [ ] export는 Phases 공유 메뉴에서 **전체** Area·Phase 필드·Task 상태·Done/사건·Inbox 포함. 현재 next-start/ID/순서 제외, Done 중복 없음. 취소/실패 처리. 가져오기 UI 없음.
- [ ] 저장 실패: 편집기/종료 확인을 유지하고 최상단 alert 하나, 재시도 가능. 참고 sheet와 error 표시가 충돌하지 않음.
- [ ] VoiceOver의 날짜/선택/별 ONOFF/아이콘 레이블, Mac 키보드·마우스, 동적 글자 크기, 다크모드, 긴 제목과 resources 확인.

## 통합/검증 기록

모든 도메인 변경은 `store.apply`를 통하고 저장 성공 뒤에만 편집기를 닫습니다. Phase 참조 화면은 읽기 전용입니다. CloudKit와 SwiftData 실행은 `Docs/DEVICE-TESTS.md`로 분리합니다. Linux 결과는 `Docs/VERIFICATION.md`와 v2 로그에 있습니다. 위 체크박스는 실제 기기에서 실행한 뒤에만 체크합니다.
