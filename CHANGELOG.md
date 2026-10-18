# 변경 이력

## 알파 v2 — 상호작용·정보 구조

### 추가
- Phases 상단 Phases / Areas 전환, 마지막 선택 기억, 완료·중단을 함께 보는 과거 국면 탐색.
- Task의 명시적인 Area / Phase 상세 이동, Task·Done 편집 위 읽기 전용 Phase 참고 및 Phase 편집 위 Inbox 참고.
- Spotlight 왼쪽 스와이프 OFF·직전 제거 Undo·기본 List 다중선택 제거와 드래그 순서 저장.
- Task 복수 Area/미소속·유형 필터, 숨김 필터 패널, 상태 기억·활성 표시·전체 초기화.
- Tasks 상단의 별도 Ended tasks 목록, 종료 최신순·완료/중단 필터.
- 같은 화면에서 5개 / More(+5) / View all / Collapse 이력·Area 작업 탐색.
- 완료/중단 확인 중 선택적 마지막 Done. 실제 Done과 사건은 보존하고 화면에서는 한 행으로 결합.
- Daily Log 주간/월간 캘린더, 수행일 점, 주 전체 기록 및 Area별 서로 다른 수행 날짜 수 요약.

### 변경
- Task 기본 정렬은 Area / Phase 이름순 그룹 + 생성 최신순. 생성일 정렬을 선택하면 평면 목록.
- 카드 탐색은 단일 목적지. Task 관리는 상세 상단 메뉴, 설명/자료는 내용이 있을 때만 확장 표시.
- Spotlight는 Area / Phase·제목·최대 2줄 재개 맥락·유형 배경색, 동기화 문구는 목록 밖 보조 영역.
- 기록/Inbox 편집·삭제를 스와이프 아이콘으로 정리. 삭제 full-swipe 즉시 실행을 막고 확인 유지. Mac 컨텍스트 메뉴도 제공.
- Phase는 Active / Completed / Stopped로 구분. 이전 archived=true 값은 읽기 시 Completed로 해석하며 데이터 자동 재작성 없음.
- Area 작업은 모든 국면·상태를 섞어 생성 최신순. 신규 Task는 미소속 기본, Phase에서 생성하면 수정 가능한 소속을 미리 선택. 생성 시 다음 시작점 필드는 생략.
- 전체 Markdown은 Phases 공유 메뉴로 접근. Phase 완료/중단 상태도 내보냄. 가져오기 없음.
- 검증 스크립트는 기존 Xcode 프로젝트를 기본 보존하고 Python gate 전체를 발견하여 실행.
- 한국어 README/설계·검증·인수 문서 정리, 공유 로그 allowlist와 cache/secret ignore 강화.

### 유지
- SwiftData 디스크 저장, private CloudKit 불변 revision 저장/결정적 병합, 저장 실패 rollback.
- 새 Done의 빈 다음 시작점은 이전 힌트를 제거. 과거 기록 수정/삭제는 현재 힌트를 바꾸지 않음.
- Phase 종료와 Task 종료 독립, Task 이동 전 이력 소속 유지, 재개 시 별 자동 복구 없음.
- + 아이콘 탭 캡처 / 0.5초 누르기 Inbox 목록의 상호 배타 제스처 및 접근성 동작.
- 자동 이월·할당량·스코어·스트릭·자동 NLP·가져오기·위젯은 추가하지 않음. 시각적 폴리시는 베타 범위.

### 검증
- Linux Swift 6.2.4: Debug / Release 각각 XCTest 37개 실패 0.
- Python 소스/구성 gate 12개 성공; iOS/macOS Swift 5 문법 파싱 성공.
- 실행 근거: `logs/v2-verification.log`, `logs/v2-source-gates.log`.
- Apple SDK 타입 검사·시뮬레이터/기기 UI·SwiftData 실제 저장 테스트·실제 iCloud는 이번 실행에서 미검증. 기본 List 두 손가락 선택도 기기 확인 필요.

## 초기 알파

Foundation 코어, Task/Phase/Area/Done/Inbox, SwiftData revision 저장, private CloudKit 구성, 로컬/Cloud 4개 공유 스킴과 전체 Markdown export를 마련했습니다. 이전 Linux 검증은 Debug/Release XCTest 31개와 구성 gate 5개이며 과거 로그에 남아 있습니다. 사용자가 Mac/Xcode 및 iPhone 시뮬레이터에서 기존 알파 실행 성공을 확인했습니다. 이를 v2 런타임 검증으로 간주하지 않습니다.
