# 검증 결과

작업 경로: `/data/playground/phase-system`.

## 이번 재개에서 실제 실행한 최종 결과

`bash Scripts/verify.sh` → **exit 0**. 전체 출력: `logs/final-verification.log`.

| 검사 | 실제 결과 | 증거 |
|---|---|---|
| Swift 6.2.4 Linux Debug XCTest | `Executed 31 tests, with 0 failures (0 unexpected) in 0.234 (0.234) seconds` | `logs/core-debug.log` |
| Swift 6.2.4 Linux Release XCTest | `Executed 31 tests, with 0 failures (0 unexpected) in 0.117 (0.117) seconds` | `logs/core-release.log` |
| Python 소스/구성 회귀 gate | `Ran 5 tests in 0.005s` / `OK` | `logs/delivery-green.log` |
| XcodeGen 2.44.1 실제 생성 | `Created project at /data/playground/phase-system/PhaseSystem.xcodeproj` | `logs/project-generation.log` |
| iOS 타깃 Swift 5 모드 문법 파싱 | exit 0 | `logs/syntax-arm64-apple-ios17.0.log` |
| macOS 타깃 Swift 5 모드 문법 파싱 | exit 0 | `logs/syntax-arm64-apple-macosx14.0.log` |
| `Scripts/*.sh` bash 문법 | 모두 exit 0 | verify.sh 전체 성공 |
| Linux에서 Apple 빌드 시도 guard | 예상한 exit 1 및 Apple SDK 필요 오류 | `logs/apple-build-unavailable.log` |

Debug/Release 최종 코어 로그에서 `warning:` 및 `error:` 행은 발견되지 않았습니다. 과거 초기 Linux 링커의 RWX 경고는 남겨 둔 `logs/core-red-green.log`에 있으며, 새 Linux 실행 스크립트는 `-z separate-code`를 사용합니다. XCTest의 31개 테스트 결과가 위 결과입니다. 뒤에 나오는 Swift Testing 라이브러리의 `0 tests` 메시지는 XCTest가 0개라는 뜻이 아닙니다.

## 재현 명령

```bash
bash Scripts/verify.sh
# 또는 개별 실행
bash Scripts/test-core.sh
PHASE_TEST_LABEL=release bash Scripts/test-core.sh -c release
python3 Tests/test_delivery.py
bash Scripts/generate-project.sh
```

Mac에서는 설치된 swift/xcodegen을 사용합니다. 이 Linux 환경에서는 폴더 안에 남아 있던 Swift 6.2.4 aarch64 툴체인과 이미 빌드된 XcodeGen 2.44.1을 재사용했습니다. 생성된 Xcode 프로젝트는 Linux 바이너리가 아니므로 Mac에서 열 수 있습니다.

## RED → GREEN 근거 / 보존한 기존 작업

- 기존 CONTRACT, 모든 App/Views 및 코어 소스/테스트, 기존 로그를 읽고 보존했습니다. 기존 프로젝트는 git 저장소가 아니므로 commit/diff/독립 PR review 결과는 없습니다.
- 재개 직후 기존 PhaseReplicaTests가 `PhaseReplica.changes` 미구현으로 실패했습니다 (`logs/resume-red.log`). 변경 revision만 생성하고 원격 형제 항목/삭제 tombstone/시계 역행을 보존하는 구현 후 30개 기존 XCTest가 성공했습니다 (`logs/resume-green.log`).
- 새 소스/구성 gate는 App entry, persistence, signing guard, 생성 프로젝트 누락을 확인해 실패했습니다 (`logs/delivery-red.log`). 이는 **소스 산출물 누락 검사**이며 실제 SwiftData 실행의 RED가 아닙니다.
- CloudKit container를 프로젝트 build setting의 빈 값이 xcconfig보다 우선하여 덮는 오류를 회귀 assertion으로 먼저 실패시킨 뒤 수정했습니다 (`logs/cloud-override-red.log`, 최종 `logs/delivery-green.log`).
- 이후 3-replica revision 전송/순서/힌트 교체 회귀 시뮬레이션을 추가하여 총 31개가 되었습니다. 이 테스트는 Foundation 값과 직렬화/병합만 검증하며 **실제 기기/CloudKit 네트워크 테스트가 아닙니다**.
- XcodeGen 첫 실행은 USER 환경변수 누락으로 실패했습니다. XcodeGen 소스의 명시적 USER 의존을 확인하고 스크립트 내부에서 `id -un` fallback을 적용한 뒤 실제 생성에 성공했습니다. 호스트 환경/접근 설정은 바꾸지 않았습니다.
- 정적 보안 점검에서 App/Sources/생성 스크립트의 하드코딩 비밀, shell=True/os.system, pickle, fatalError, try! 패턴은 발견되지 않았습니다. 전문 보안 감사는 아닙니다.

## 아직 실행하지 못한 것

**Apple SDK가 없는 Linux에서 다음 성공은 주장하지 않습니다.**

- Xcode iOS/macOS 빌드 및 SwiftUI/SwiftData 매크로·API 타입 검사.
- SwiftData 실제 디스크 저장/재열기 및 실패 롤백. `Tests/ApplePersistenceTests/PersistenceTests.swift`의 3개 테스트는 추가했지만 여기서 실행하지 못했습니다.
- 앱 화면/탐색/sheet/드래그/파일 exporter/URL 열기/VoiceOver.
- entitlement와 개발팀의 실제 프로비저닝, CloudKit 개발/운영 schema 배포, 계정 변경.
- iPhone/iPad/Mac의 실제 데이터·Spotlight 순서 전파와 오프라인 재실행/재연결.

Mac 실행 명령: `bash Scripts/build-apple.sh local`, `bash Scripts/build-apple.sh test`. 실제 팀/컨테이너 설정 후 `bash Scripts/build-apple.sh cloud` 및 `Docs/DEVICE-TESTS.md`, `Tests/UIAcceptance.md`를 수행합니다.

## 산출물 핵심 경로

- 앱 진입점: `App/PhaseSystemApp.swift`
- SwiftData/CloudKit 영속 계층: `App/Persistence.swift`
- 보존한 UI: `App/Views/*.swift`
- 실제 생성된 프로젝트: `PhaseSystem.xcodeproj/project.pbxproj`, 공유 스킴 4개
- 재생성 원본: `project.yml`, `Config/*`, `Scripts/generate-project.sh`
- 사용/서명/제약: `README.md`
- 실기기 테스트: `Docs/DEVICE-TESTS.md`

동일 항목 동시 편집은 필드별 병합이 아니라 전체 항목 LWW입니다. 예를 들어 같은 작업을 한 기기에서 별 변경, 다른 기기에서 Done/힌트 변경하면 최신 작업 revision의 별 상태가 이길 수 있습니다. 수행 기록 자체는 별도 엔트리라 보존됩니다. 이 한계와 모든 revision 누적으로 인한 저장/성능 한계는 README에 명시했습니다.
