# 알파 v2 검증 결과

작업 경로: `/data/playground/phase-system`. 이번 작업은 Linux에서 실행했습니다. 기존 알파가 사용자 Mac/Xcode와 iPhone 시뮬레이터에서 실행된 사실과 **이번 v2를 직접 실행한 검증**을 구분합니다.

## 실제 실행 결과

```bash
set -o pipefail
bash Scripts/verify.sh 2>&1 | tee logs/v2-verification.log
```

위 명령은 **exit 0**입니다.

| 검사 | 실제 결과 | 근거 |
|---|---|---|
| Swift 6.2.4 / Linux Debug XCTest | 37개, 실패 0 | `logs/v2-verification.log`의 debug.xctest / All tests |
| Swift 6.2.4 / Linux Release XCTest | 37개, 실패 0 | 같은 로그의 release.xctest / All tests |
| Python 소스·구성 gate | 12개, OK | `logs/v2-source-gates.log` |
| iOS Swift 5 모드 문법 파싱 | `arm64-apple-ios17.0`, exit 0 | 통합 로그의 Syntax only / PASS |
| macOS Swift 5 모드 문법 파싱 | `arm64-apple-macosx14.0`, exit 0 | 통합 로그의 Syntax only / PASS |
| `Scripts/*.sh` bash 문법 | 모두 성공 | `verify.sh` 전체 exit 0 |
| 기존 Xcode 프로젝트 보존 | 재생성 생략 | 통합 로그 첫 줄 |

XCTest 출력 뒤의 Swift Testing 라이브러리 `0 tests`는 별도 러너의 결과입니다. XCTest 37개가 0개라는 뜻이 아닙니다. 이 결과는 SwiftUI/SwiftData SDK 타입 검사나 앱 실행 결과가 아닙니다.

## 무엇을 실행해서 확인했는가

- 기존 31개 코어 테스트: Done/힌트 교체, 수행일 정렬, 삭제 범위, 종료/재개, Task-only Spotlight와 순서, 스냅샷 소속, 전체 Markdown, revision 병합/삭제 tombstone/오프라인 3-replica 값 시뮬레이션을 유지했습니다.
- v2 코어 6개: 과거 archived Phase 호환·상태 전환·하위 Task 독립, Phase 상태 검증/Markdown, 선택적 마지막 Done과 종료의 원자성/화면 통합/삭제 후 사건 보존, 마지막 Done 날짜 정정, 예전 JSON의 선택 필드 누락 호환, 주간 Area별 고유 수행 날짜 집계를 검증합니다.
- Python 12개 중 v2 gate 6개는 **소스 문자열 계약 검사**입니다. 필요한 화면 구조/제거된 문구/선택·스와이프·저장 API 연결/캘린더·집계 연결/ignore 및 검증 스크립트 설정을 확인할 뿐 실제 화면의 선택·스와이프·탐색 성공을 증명하지 않습니다.
- 나머지 Python gate는 기존 Inbox 상호 배타 제스처 소스 및 앱·저장·Cloud 설정 산출물, Cloud 구성 누락 guard의 실제 shell 실행을 확인합니다.

## RED → GREEN 기록

코어 테스트와 UI 소스 gate를 먼저 추가한 뒤 실제 실패를 확인하고 구현했습니다. 중간 출력은 로컬 `logs/core-v2-*-red.log`, `logs/v2-ui-*-red.log` 등에 보관되지만 기본 공유 대상은 아닙니다.

- Phase API·마지막 Done 연결·주간 집계 API가 없어서 각 새 코어 테스트가 컴파일 실패한 뒤 구현 후 성공했습니다. 이 RED는 구현하지 않은 API의 부재이며 런타임 실패라고 주장하지 않습니다.
- Phase export/검증 회귀는 실제 XCTest assertion 3개가 실패했고, 마지막 Done 날짜 정정 후 잘못 남는 lifecycle badge는 assertion 1개가 실패했습니다. 구현 후 최종 전체 스위트가 성공했습니다.
- 중간 전체 실행에서 기존 Markdown `보관` 보존 assertion 1개가 실패했습니다. 새 상태 표시와 기존 보관 정보가 모두 내보내지도록 수정하여 기존 테스트도 유지했습니다.
- UI gate의 RED는 필요한 소스가 없어서 실패한 것입니다. SwiftUI 런타임 테스트의 RED가 아닙니다.

## 재현

```bash
bash Scripts/verify.sh
# 개별 실행
bash Scripts/test-core.sh
PHASE_TEST_LABEL=release bash Scripts/test-core.sh -c release
python3 -m unittest discover -s Tests -p 'test_*.py' -v
# 프로젝트 재생성이 정말 필요한 경우만 (기존 프로젝트를 변경함)
PHASE_REGENERATE_PROJECT=1 bash Scripts/verify.sh
```

설치된 Swift 또는 `SWIFT` 환경변수의 컴파일러를 사용합니다. 이 Linux 실행은 `.tools`에 있던 Swift 6.2.4 툴체인을 재사용했습니다. SwiftUI 파일은 `swiftc -frontend -parse -swift-version 5 -target <target>`로 파싱하며 import 해석·API 가용성·매크로 확장·타입 검사를 수행하지 않습니다.

## Mac에서 남은 필수 확인

1. `PhaseSystem.xcodeproj` → PhaseSystem / iPhone 시뮬레이터 Run, PhaseSystemMac / My Mac Run. 이번 v2의 SwiftUI API·뷰 빌더 타입 확인이 우선입니다.
2. `bash Scripts/build-apple.sh local`, `bash Scripts/build-apple.sh test`: 실제 Apple 빌드와 SwiftData 저장/재열기/롤백/컨텍스트 갱신 테스트.
3. `Tests/UIAcceptance.md` 전 항목: 특히 Edit 선택 원·재정렬 핸들 동시 표시, native 두 손가락 선택 지원, 왼쪽 스와이프, Undo 순서, 참조 sheet 닫은 뒤 초안 유지, picker Area 머리글, 주간 날짜 스크롤.
4. 실제 팀/컨테이너 설정 후 `bash Scripts/build-apple.sh cloud`, `Docs/DEVICE-TESTS.md`의 iPhone/iPad/Mac 오프라인·동기화 시나리오.
5. VoiceOver/키보드/마우스, 긴 글/큰 글자/가로 모드, export 파일과 안전한 URL 열기, 저장 실패 때 맨 위 alert 및 초안 유지.

**미실행:** Apple SDK 타입 검사, SwiftData 매크로 및 디스크 XCTest, 시뮬레이터/기기 UI, 실제 iCloud 프로비저닝·schema·전송. UIKit 브리지를 만들거나 두 손가락 선택이 검증되었다고 꾸미지 않았습니다.

## 보존 범위 / 공유 안전

- 기존 `App/Persistence.swift`, 앱 진입점, Cloud 서명 설정, Xcode 프로젝트/사용자 scheme 상태는 이번 v2에서 바꾸지 않았습니다. 읽기만으로 도메인 데이터 마이그레이션/Cloud revision 쓰기를 수행하지 않습니다.
- `.gitignore`는 캐시/생성물/개인 Xcode 상태/인증서/환경파일/로컬 DB·기본 export를 제외하고 새 공유 로그는 `v2-verification.log`, `v2-source-gates.log`만 허용합니다.
- 사용자가 작업 중 만든 Git 저장소와 기존 staged 변경을 보존했습니다. Git index 변경·init·remote 수정·commit·push는 수행하지 않았습니다. **이미 staged된 과거 로그/`.swiftpm` 파일은 ignore만으로 index에서 사라지지 않습니다.** 사용자 업로드 전 점검이 필요합니다.
- 공유 후보 80개 파일을 대상으로 고신뢰 자격 패턴(GitHub/AWS 토큰·private key·길게 하드코딩된 secret 등)을 점검해 일치 0, 캐시/개인 Cloud 설정/인증서/DB 경로 후보 0을 확인했습니다. `git check-ignore --no-index`로 .tools/.build/Scripts/.cache/Cloud.xcconfig/DerivedData/.env/인증서/DB/일반 로그 제외도 확인했습니다. 전문 보안 감사나 개인정보 부재 보증은 아닙니다.
- 이번 점검 시 이미 staged된 과거 로그와 `.swiftpm` workspace 파일은 합계 27개였습니다. 원래 index를 바꾸지 않았으므로 사용자 커밋 전에 선별해야 합니다. 코드·문서의 `git diff --check`(로그 제외)는 성공했습니다. 전체 cached check는 기존 과거 RED 로그의 trailing whitespace를 보고했으며 로그와 index를 임의로 고치지 않았습니다. 개인 Cloud 설정/자격을 생성하거나 출력하지 않았습니다.

## 이전 알파 기록

기존 `logs/final-verification.log` 및 Debug/Release 31개 결과, XcodeGen 2.44.1 생성 결과는 **이전 알파 작업의 기록**입니다. 당시 저장소가 없었다는 설명을 현재 상태로 해석하면 안 됩니다. 기존 로컬 로그는 삭제하지 않았으며 새 기본 공유 목록에서는 제외했습니다. 현재 판단은 위 v2 통합 로그를 기준으로 합니다.
