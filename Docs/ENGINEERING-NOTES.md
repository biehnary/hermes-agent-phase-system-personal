# 이 프로젝트의 재개/검증 절차

- 작업 위치를 `/data/playground/phase-system`으로 고정한다. .git 존재를 먼저 확인하며 없으면 diff/commit 성공을 주장하지 않는다. 기존 소스와 로그를 읽은 뒤 수정한다.
- sleep/중단 이후에는 실행 중 프로세스와 남아 있는 도구를 먼저 확인한다. `.tools/*/usr/bin/swift`, `Scripts/.cache/XcodeGen/.build/*/release/xcodegen`이 있으면 불필요한 재설치/중복 빌드를 시작하지 않는다. Linux 바이너리를 Mac에 설치하지 않는다.
- XcodeGen은 USER가 없는 최소 Linux 환경에서 실패한다. `Scripts/generate-project.sh`처럼 프로세스 내부에만 `USER=${USER:-$(id -un)}`를 설정한다. 호스트 설정을 바꾸지 않는다.
- Xcode project build settings는 xcconfig 값을 덮을 수 있다. 컨테이너/팀을 프로젝트 설정의 빈 기본값으로 중복 정의하지 않는다. Local/Cloud 구성을 분리하고 동일 bundle ID/저장 경로와 같은 CloudKit 컨테이너를 유지한다.
- 새로운 동작은 실패하는 코어 테스트를 먼저 실행하고 구현한다. Apple SDK가 없으면 실제 SwiftData XCTest를 실행한 것처럼 기록하지 않는다. 소스 gate, 문법 파싱, revision 전송 시뮬레이션을 Apple 타입 검사/디스크/CloudKit 검증과 분리해 보고한다.
- `bash Scripts/verify.sh`로 실제 Debug/Release 코어 결과, 모든 Python 소스/구성 gate와 문법 파싱 결과를 한 번에 기록한다. 기존 Xcode 프로젝트가 있으면 기본 보존하며 재생성은 `PHASE_REGENERATE_PROJECT=1`로 명시한다. 기존 사용자 프로젝트/서명 설정을 검증 중 무심코 덮어쓰지 않는다. XCTest 결과와 뒤에 붙는 별도 Swift Testing의 0개 메시지를 혼동하지 않는다.
- 실제 Apple 빌드는 Mac의 `Scripts/build-apple.sh`, 세 기기/오프라인 인수는 `Docs/DEVICE-TESTS.md`로 수행한다. 마지막 사용자 보고는 성공한 것/미검증 항목과 증거 경로만 짧게 전달한다.
