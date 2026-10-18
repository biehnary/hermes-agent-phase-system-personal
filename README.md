# Phase System — Swift alpha

기본 UI와 도메인 코어, 실제 SwiftData 디스크 저장 및 SwiftData의 private CloudKit 동기화 경로를 갖춘 iPhone / iPad / Mac 알파입니다. iOS 17+, macOS 14+, Xcode 16+를 대상으로 합니다. 타이머·할당량·마감일·스트릭·자동 작업 이월은 없습니다.

**검증 경계:** Linux에서 코어 XCTest와 구성 회귀 검사, XcodeGen 프로젝트 생성, Apple 타깃 Swift 문법 파싱을 실행했습니다. Apple SDK가 없어 SwiftUI/SwiftData 타입 검사, Xcode 빌드, 앱 실행, 실제 iCloud 동기화는 아직 검증하지 못했습니다. 코드는 동기화 모의 구현이 아니지만, 기기 검증 완료 제품이라는 뜻은 아닙니다. 세부 결과는 `Docs/VERIFICATION.md`를 확인하세요.

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
5. 프로젝트 재생성이 필요할 때만 `brew install xcodegen` 후 `bash Scripts/generate-project.sh`를 실행합니다. 최소 XcodeGen 2.44.1입니다. `Scripts/create-delivery.py`는 최초 산출물 생성용이며 기존 Identity 설정이 있으면 덮어쓰지 않고 종료합니다. 이후에는 `project.yml`을 편집하고 regenerate하세요.

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

- **Phases**: Area는 제목·설명 중심의 가벼운 분류입니다. Phase에는 목표/현재 상황/병목/주관적 기대 변화를 적습니다. 통과 조건·기한을 강제하지 않습니다. 보관해도 하위 작업이 종료되거나 이월되지 않습니다.
- **Tasks**: 전체 작업을 Phase/미소속 그룹으로 봅니다. 일반/빠른 작업은 Phase 소속과 독립입니다. 검색·유형 필터·종료 작업 표시를 지원합니다. 기본 수동 순서이며, 선택적으로 마지막 실제 수행이 오래된 순서로 읽을 수 있습니다. 한 달 표시도 마지막 수행일 기준의 중립 문구이고, 기록 없는 작업의 생성일을 대신 쓰지 않습니다.
- **Spotlight**: 선택한 작업만 유형/Phase 구분 없이 한 목록에 나타납니다. ON/OFF는 원본을 보존하고, 새로 올린 작업은 맨 아래에 들어갑니다. iPhone/iPad Edit 드래그 또는 Mac 드래그/컨텍스트 메뉴 위·아래로 순서를 바꿉니다. 순서/ON 상태도 영속 저장·CloudKit 동기화 대상입니다.
- **작업 상세**: Record Done → 오늘 기본/수정 가능한 수행일 + 한 일 + 선택 메모 + 선택 다음 시작점을 저장합니다. **새 기록은 항상 이전 다음 시작점을 교체합니다. 빈칸이면 이전 힌트가 지워지고 수행일 기준 최신 Done 본문을 보여 줍니다.** 다른 작업의 힌트에는 영향이 없습니다. 과거 기록 본문 수정은 수정 시각 때문에 최신 수행으로 올라오지 않습니다. 수행일 자체 정정은 정정한 날짜로 정렬됩니다.
- **완료/중단**: 별도 수명주기 사건으로 남기며 Spotlight와 기본 진행 목록에서 숨깁니다. 다시 열면 기록을 유지하고 별을 자동 복구하지 않습니다. 종료 사건 자체는 Done/히트맵 표시가 아닙니다.
- **Daily Log**: 실제 기록 있는 날짜만 나열합니다. 수행 날짜마다 같은 한 칸만 표시하며 수행 횟수/농도/스트릭은 없습니다. 작업 없는 독립 Done도 가능합니다. 작업·Phase·Area·날짜 화면은 같은 기록을 참조합니다.
- **떠 있는 + Inbox dump**: 현재 탭/상세를 유지한 채 분류 없이 자유 텍스트만 캡처합니다. Add Task/Record Done은 별도 이름의 동작입니다. Inbox 목록에서 편집/확인 후 삭제가 가능합니다. 전환 기능은 이번 범위에 없습니다.
- **Actions → Export all Markdown**: 영역/국면 전체 필드, 작업 유형/현재 상태, 보관 내용, 날짜 있는 수행·메모·수명주기 이력, 인박스를 하나의 읽을 수 있는 `.md` 파일로 내보냅니다. Spotlight 순서/내부 ID/현재 next-start는 내보내지 않습니다. 기록은 한 번씩만 포함됩니다. JSON 내보내기·복구·가져오기는 없습니다. Markdown은 복원용 백업이 아닙니다.

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

실행 로그는 `logs/`, 재현 명령과 검증 한계는 `Docs/VERIFICATION.md`에 있습니다.
