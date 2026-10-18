# Phase System — 알파 v2

기본 UI와 도메인 코어, 실제 SwiftData 디스크 저장 및 SwiftData의 private CloudKit 동기화 경로를 갖춘 iPhone / iPad / Mac 알파입니다. iOS 17+, macOS 14+, Xcode 16+를 대상으로 합니다. 타이머·할당량·마감일·스트릭·자동 작업 이월은 없습니다.

## 목적과 현재 개발 단계

진행 중인 일의 **맥락을 남기고, 다시 시작할 지점을 찾기 위한 개인용 도구**입니다. Area는 오래 유지되는 가벼운 분류, Phase는 현재의 목표·상황·병목이 바뀌는 국면, Task는 수행을 이어가는 단위입니다. Done은 실제로 수행한 사실을 기록합니다. 계획량을 채우거나 활동량을 평가하는 앱은 아닙니다.

현재는 **알파 v2 — 상호작용과 정보 배치 구현 단계**입니다. 기존 알파의 Mac/Xcode·iPhone 시뮬레이터 실행 성공은 사용자 확인 사항이며, 이번 v2를 기기에서 다시 실행한 결과는 아닙니다. 카드 배경색은 General/Quick 구분을 위한 임시값이고, 정교한 비주얼·전체 현지화·위젯은 베타 이후 범위입니다.

**검증 경계:** Linux에서 코어 XCTest와 구성 회귀 검사, XcodeGen 프로젝트 생성, Apple 타깃 Swift 문법 파싱을 실행했습니다. Apple SDK가 없어 SwiftUI/SwiftData 타입 검사, Xcode 빌드, 앱 실행, 실제 iCloud 동기화는 아직 검증하지 못했습니다. 코드는 동기화 모의 구현이 아니지만, 기기 검증 완료 제품이라는 뜻은 아닙니다. 세부 결과는 `Docs/VERIFICATION.md`를 확인하세요.

이번 v2 검증은 `bash Scripts/verify.sh` **exit 0**, Debug/Release 각각 **37개 XCTest 실패 0**, Python 소스·구성 gate **12개 성공**, iOS/macOS **문법 파싱 성공**입니다. 근거는 `logs/v2-verification.log`, `logs/v2-source-gates.log`입니다. 기존 Xcode 프로젝트는 재생성하지 않고 보존했습니다. 소스 gate는 실제 UI 동작 검증이 아닙니다.

## Mac에서 먼저 실행

1. 전체 폴더를 Mac의 쓰기 가능한 위치로 복사합니다. `.tools`, `.build`, `Scripts/.cache`는 Linux 전용 캐시이므로 복사할 필요 없습니다. `App`, `Sources`, `Tests`, `Config`, `Scripts`, `Package.swift`, `project.yml`, `PhaseSystem.xcodeproj`는 함께 유지합니다.
2. `PhaseSystem.xcodeproj`를 Xcode로 엽니다. 외부 패키지 다운로드 없이 루트의 로컬 `PhaseCore` 패키지를 참조합니다.
3. 시뮬레이터는 **PhaseSystem** 스킴, Mac은 **PhaseSystemMac** 스킴을 선택해 Run합니다. 이 두 스킴의 Debug는 서명 없는 로컬 저장 전용입니다. 이 빌드가 iCloud 동기화한다고 표시하지 않습니다.
4. 선택 사항인 터미널 검증:
   ```bash
   bash Scripts/test-core.sh
   bash Scripts/build-apple.sh local
   bash Scripts/build-apple.sh test
   ```
   마지막 명령은 Mac에서 실제 SwiftData 디스크 재열기/저장 실패 롤백/별도 컨텍스트 갱신 테스트를 수행합니다. 현재 Linux에서 이 테스트가 통과했다는 주장은 하지 않습니다.
5. 프로젝트 재생성이 필요할 때만 `brew install xcodegen` 후 `bash Scripts/generate-project.sh`를 실행합니다. 최소 XcodeGen 2.44.1입니다. `Scripts/create-delivery.py`는 최초 산출물 생성용이며 기존 Identity 설정이 있으면 덮어쓰지 않고 종료합니다. 이후에는 `project.yml`을 편집하고 regenerate하세요. v2는 기존 프로젝트로 바로 빌드할 수 있습니다. `verify.sh`도 기존 프로젝트가 있으면 보존하며, 명시적으로 재생성하려면 `PHASE_REGENERATE_PROJECT=1 bash Scripts/verify.sh`를 사용합니다.

## iCloud를 사용하는 실제 기기 빌드

유료 Apple Developer 팀, 동일 Apple 계정으로 로그인한 기기, 해당 계정의 iCloud Drive 활성화가 필요합니다. 이 저장소에 실제 Team ID/개인 컨테이너 ID/자격 증명을 넣어 두지 않았습니다.

1. `Config/Identity.xcconfig`의 두 bundle identifier를 소유한 고유 ID로 **한 번** 변경합니다. iOS/iPadOS는 같은 ID, Mac은 별도 ID입니다. 이후 Local↔Cloud 전환 시 bundle ID를 바꾸지 않아 같은 앱 저장소를 유지합니다. 배포 이후 ID를 바꾸면 다른 앱/저장소가 됩니다.
2. Apple Developer 포털에서 두 App ID 모두 iCloud(CloudKit)와 Push Notifications를 활성화하고, **같은 하나의 CloudKit 컨테이너**를 연결합니다. Xcode Signing & Capabilities에서도 두 타깃에 같은 컨테이너와 팀이 선택되었는지 확인합니다. iOS Background Modes의 Remote notifications는 Info plist에 포함되어 있습니다.
3. `Config/Cloud.example.xcconfig`를 `Config/Cloud.xcconfig`로 복사해 빈 값을 채웁니다:
   ```text
   DEVELOPMENT_TEAM = <본인의 Apple 팀 ID>
   PHASE_CLOUDKIT_CONTAINER = <본인의 iCloud.로 시작하는 컨테이너 ID>
   CODE_SIGN_STYLE = Automatic
   CODE_SIGNING_ALLOWED = YES
   ```
   실제 값을 꺾쇠괄호 없이 입력합니다. 이 파일은 gitignore 대상입니다. CloudDebug/CloudRelease만 이 파일을 읽습니다. Local.xcconfig는 컨테이너를 비워 두어 CloudKit을 켜지 않습니다.
4. iPhone/iPad는 **PhaseSystemCloud**, Mac은 **PhaseSystemMacCloud** 스킴을 사용합니다. CloudDebug는 Development 환경/개발 push entitlement, CloudRelease는 Production 환경/production push entitlement입니다. 팀·컨테이너 누락은 pre-build 검증에서 실패합니다. 잘못된 등록/권한은 서명 또는 런타임 CloudKit 오류로 표시됩니다.
5. Xcode에서 실제 기기를 선택해 Run합니다. CLI 빌드는 `bash Scripts/build-apple.sh cloud`입니다. 이 명령의 `-allowProvisioningUpdates`는 Mac에서 프로비저닝을 요청하므로 직접 실행할 때만 사용합니다. 이 Linux 작업에서는 실행하지 않았습니다.
6. Development 빌드를 실행해 초기 데이터/동기화 작업을 만든 다음 CloudKit Console에서 개발 스키마가 만들어지고 데이터가 저장되는지 확인합니다. TestFlight/배포 전에 Apple 안내에 따라 **Deploy Schema Changes to Production**을 수행합니다. Development 데이터 자체는 Production으로 복사되지 않습니다. 세 기기는 반드시 같은 환경으로 테스트합니다.
7. `Docs/DEVICE-TESTS.md`의 오프라인 및 세 기기 검증을 수행합니다. Spotlight의 동기화 문구는 CloudKit 이벤트/계정 상태이며, 다른 기기의 수신 완료를 보장하는 영수증은 아닙니다.

## 사용 흐름

- **Phases / Areas**: Phases 화면 상단에서 전환합니다. 마지막 전환 상태를 기억하며 별도 하단 Area 탭은 없습니다. Phase는 Active / Completed / Stopped를 구분하고 `Show past phases`로 완료·중단 국면을 함께 봅니다. Phase를 닫아도 하위 작업은 그대로입니다. Area 상세 작업은 모든 국면과 상태를 섞어 생성 최신순으로 표시합니다.
- **Tasks**: 기본은 Area / Phase 이름순 그룹, 그룹 안은 생성 최신순입니다. 생성 최신순/오래된순을 선택하면 그룹 없는 평면 목록이 됩니다. 필터 버튼 안에서 복수 Area(미소속 포함)와 All / General / Quick를 선택하고 `Clear all`로 초기화합니다. 필터·정렬은 화면을 떠나도 유지됩니다. 종료 작업은 상단 `Ended tasks`에서 종료 최신순과 Completed / Stopped 필터로 따로 봅니다. Spotlight 필터와 마지막 수행일 정렬은 없습니다.
- **카드와 이동**: Task 카드의 탐색 목적지는 항상 Task 상세 하나입니다. 카드 일부를 눌러 Phase로 가는 숨은 분기는 없습니다. Tasks의 별 ON/OFF는 명시적인 별도 조작입니다. 상세의 Area / Phase 버튼으로 Phase를 엽니다. General/Quick는 이름과 절제된 다른 배경색으로 구분합니다.
- **Spotlight**: 별표 작업만 한 목록에 나타나고 새 별은 맨 아래에 추가됩니다. 왼쪽 스와이프로 확인창 없이 OFF, 하단 `Undo`로 직전 제거를 복구합니다. Edit에서 기본 List 선택과 재정렬 핸들을 함께 사용하며 선택 항목을 한 번에 제거할 수 있습니다. 위/아래 이동 컨텍스트 메뉴는 제거했습니다. iOS 기본 두 손가락 다중선택은 프레임워크 지원 범위에 맡겼고, 실제 기기 동작 보장은 아직 없습니다. Mac은 기본 다중선택·드래그 사용을 확인해야 합니다. 동기화 상태는 목록 행이 아닌 보조 문구입니다.
- **작업 상세 / Done**: 현재 재개 맥락을 위에, 이력을 최신 5개부터 아래에 표시합니다. 설명·자료는 있을 때 펼쳐 보이고 빈 섹션은 생략합니다. `More`는 5개 추가, 왼쪽 `View all`은 같은 화면 전체 펼침, `Collapse`는 5개로 돌아갑니다. 편집/이동/유형 변경/별/완료/중단/재개는 상단 메뉴에 모았습니다. Done은 오늘 기본/수정 가능한 수행일 + 한 일 + 선택 메모 + 선택 다음 시작점을 저장합니다. **새 Done은 이전 다음 시작점을 항상 교체합니다. 빈칸이면 이전 힌트를 지우고 수행일 기준 최신 Done 본문으로 재개합니다.** 과거 기록의 수정/삭제는 현재 힌트를 바꾸지 않습니다.
- **참고하며 입력**: Task·Done 편집 중 `Phase reference`는 편집기 위에 읽기 전용 Phase를 엽니다. 닫으면 같은 미저장 초안으로 돌아옵니다. Phase 편집 중에는 선택적으로 읽기 전용 `Inbox reference`를 열 수 있습니다. Task 생성에서는 다음 시작점 필드 없이 설명에 최초 의도를 적습니다. Phase 선택기는 Area 머리글로 묶으며 종료 국면은 신규 선택에서 제외하고 기존 선택값은 표시합니다.
- **완료/중단**: 확인 화면에 선택적으로 마지막 Done 본문을 적을 수 있습니다. 빈칸이면 수명주기 사건만, 본문이 있으면 실제 Done과 사건을 한 트랜잭션에 저장하고 UI에서는 한 행으로 표시합니다. 따라서 종료만으로 수행일 점이 생기지 않습니다. 다시 열어도 별은 자동 복구하지 않습니다. 기록 행 편집/삭제는 trailing swipe 아이콘(또는 Mac 컨텍스트 메뉴)이며 삭제는 별도 확인합니다.
- **Daily Log**: 처음에는 Week, 이후 마지막 Week / Month 모드를 기억합니다. 월간은 월 이동·전체 달력·선택일 기록, 주간은 주 이동·가로 날짜와 한 주 전체 기록입니다. 주간 날짜를 누르면 해당 날짜 위치로 이동하며 주 전체를 필터링하지 않습니다. 실제 Done이 있는 날만 같은 작은 점으로 표시합니다. 주간 Area 요약 `Area · N days`는 기록 개수가 아닌 **서로 다른 수행 날짜 수**이며 독립 Done은 Unassigned에 포함됩니다. 빈 선택일에는 `No records` 한 줄만 표시합니다. 잔디 화면·스트릭·위젯은 만들지 않았습니다.
- **떠 있는 + Inbox dump**: 아이콘만 표시합니다. 탭은 자유 텍스트 캡처, 0.5초 누르기는 Inbox 목록입니다. 두 제스처는 상호 배타적이며 접근성 기본 동작/이름 있는 목록 열기도 제공합니다. 저장/취소 뒤 같은 화면을 유지합니다. Inbox 편집/삭제도 아이콘 스와이프와 확인을 사용합니다. Task로의 자동 전환은 없습니다.
- **Phases의 공유 메뉴 → Export all Markdown**: 선택한 Phase만이 아니라 영역/국면 전체 필드, 작업 유형·상태, 보관 내용, 수행·메모·수명주기 이력, Inbox 전체를 `.md` 하나로 내보냅니다. 내부 ID/Spotlight 순서/현재 다음 시작점은 제외합니다. Done과 사건은 내보내기에서 각각 사실대로 한 번씩 남습니다. 가져오기·JSON 복원은 없으며 Markdown은 복원용 백업이 아닙니다.

## 중요한 설계 결정과 이유

- **Task 유형·Phase 상태·Task 수명주기는 독립**: 국면을 정리하는 것과 할 일을 끝내는 것을 혼동하지 않도록 했습니다. 종료 Phase의 활성 Task도 현재 Tasks에 남습니다.
- **이력의 소속은 수행 당시 스냅샷**: Task를 옮기거나 Phase의 Area를 바꿔도 과거 기록의 맥락을 다시 쓰지 않습니다. 주간 요약도 이 스냅샷으로 집계합니다.
- **마지막 수행과 수정 시각을 분리**: 과거 메모 편집을 새 활동으로 추론하지 않습니다. Task 목록 날짜 정렬은 생성 시각만, 종료 목록은 종료 사건 시각을 사용합니다.
- **현재 재개 힌트는 교체 가능한 상태**: 모든 Done에 다음 시작점 이력을 쌓지 않습니다. 오래된 안내를 새 기록 뒤에도 남기는 오류를 방지합니다.
- **오프라인 우선·명시적인 저장**: 조회/모드 변경은 도메인 revision을 쓰지 않습니다. 상태 필터는 기기 로컬 UserDefaults이며 CloudKit 공유 대상이 아닙니다. 편집은 저장 성공 뒤에만 닫힙니다.
- **이전 데이터 호환**: 기존 Phase의 `archived=true` + `lifecycle=active`는 읽을 때 Completed로 해석하고 자동 마이그레이션 쓰기는 하지 않습니다. 명시적인 상태 변경부터 기존 lifecycle/archived 필드로 저장합니다. 마지막 Done 연결에는 선택적 `linkedDoneID`만 추가하여 예전 JSON도 읽습니다. 세부사항: `CONTRACT.md`, `Docs/ALPHA-V2.md`.

## 구조와 실제 동기화 방식

- `Sources/PhaseCore`: Foundation 전용 모델/검증/원자적 값 변경/Markdown/결정적 revision 병합. Linux에서 실제 컴파일·실행됩니다.
- `App/Persistence.swift`: CloudKit 호환 기본값과 관계 없는 scalar 필드의 `@Model RevisionEntity`; 엔트리를 불변 revision으로 추가 저장합니다. 로컬 SQLite 저장은 ModelContainer가 관리하며, Cloud 빌드에서는 `.private(containerID)`를 사용합니다. UI 저장은 새 컨텍스트에서 읽기 → 변경 검증 → revision 추가 → `context.save()` 성공 후 상태 갱신입니다. 실패 시 rollback하고 편집기를 유지합니다. 저장소 시작 실패를 임시 메모리 저장소로 숨기지 않습니다.
- `PhaseReplica`: 항목별 수정 시각 → revision UUID → 결정적 payload 순서로 승자를 선택합니다. 삭제는 tombstone으로 보존합니다. 서로 다른 작업의 오프라인 추가는 합쳐지고, 같은 항목의 동시 편집은 **전체 항목 last-writer-wins**입니다. 동일 기기의 시계 역행은 키별 timestamp 증가로 방어하지만 기기 간 큰 시계 오차는 해결하지 않습니다.
- SwiftData/CloudKit 프레임워크가 업로드·다운로드/재시도를 처리합니다. CloudKit event notification, remote-store notification, 활성 화면의 5초 간격 로컬 재조회로 UI를 갱신합니다. 5초 재조회는 네트워크 동기화 강제가 아닙니다. 서버나 자체 REST 동기화 스텁은 없습니다.

## 알려진 한계 / 아직 남은 검증

- Apple SDK 테스트가 남아 있습니다. `Tests/ApplePersistenceTests`의 3개 테스트와 `Tests/UIAcceptance.md`의 UI/접근성 검증을 Mac에서 수행해야 합니다. 실제 세 기기 동기화도 별도입니다.
- 다중 기기가 같은 작업/순서를 동시에 변경하면 마지막 revision 승자 기준입니다. 필드 단위/사용자 선택 충돌 해결이나 순서 CRDT는 아닙니다. 여러 작업으로 구성된 순서 변경은 로컬에서 원자적이나 CloudKit에서 일부 revision이 먼저 도착할 수 있어 잠깐의 중간 순서를 볼 수 있습니다.
- 모든 revision/tombstone을 보존하고 전부 읽습니다. 아직 compaction/페이지 처리/대용량 최적화가 없습니다. 텍스트/URL 위주 알파이며 파일 첨부나 CloudKit 한도를 넘는 매우 큰 본문은 지원 검증하지 않았습니다.
- iCloud 로그인 전환/계정 변경 격리, 로컬→클라우드 기존 대량 데이터 전환, CloudKit 서버 오류 복구는 실제 기기에서 별도 검증이 필요합니다. 알파에서 계정을 바꾸며 실데이터를 혼합하지 말고 먼저 Markdown을 내보내세요. 앱 삭제/개발 컨테이너 리셋은 데이터를 잃을 수 있으므로 문제 해결용 기본 절차로 권하지 않습니다.
- UI는 최소 기능 중심이며 영문 버튼/한글 오류가 섞여 있습니다. 아이콘/비주얼 폴리시/전체 현지화는 후속입니다. Xcode의 앱 아이콘 관련 경고가 있을 수 있으며 스토어 제출용 완성본은 아닙니다.

## 테스트 재현과 공유 전 점검

```bash
bash Scripts/verify.sh
# 필요하면 개별 실행
bash Scripts/test-core.sh
PHASE_TEST_LABEL=release bash Scripts/test-core.sh -c release
python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

Linux 툴체인은 저장소에 포함하지 않습니다. 설치된 Swift 또는 `SWIFT=/경로/swift`를 사용할 수 있습니다. 모든 UI 인수 항목은 `Tests/UIAcceptance.md`, 변경이력은 `CHANGELOG.md`에 있습니다.

`.gitignore`는 `.tools`, `.build`, `Scripts/.cache`, `.swiftpm`, DerivedData/빌드 산출물, 사용자 Xcode 상태, `Config/Cloud.xcconfig`, 환경 파일, 인증서/프로비저닝, 로컬 데이터베이스와 기본 Markdown 내보내기를 제외합니다. 공유 로그는 검토한 `logs/v2-verification.log`, `logs/v2-source-gates.log`만 새로 허용합니다. **이미 staged/tracked인 파일은 ignore로 제외되지 않습니다.** 기존 index는 이번 작업에서 바꾸지 않았으므로 업로드 전에 `git diff --cached --name-only`와 실제 내용을 확인하세요. 로그·스크린샷·임의 이름의 Markdown에는 개인 기록이 섞일 수 있으므로 따로 검토해야 합니다. GitHub 연결·커밋·푸시는 사용자가 담당합니다.

실행 로그는 `logs/`, 재현 명령과 검증 한계는 `Docs/VERIFICATION.md`에 있습니다.
