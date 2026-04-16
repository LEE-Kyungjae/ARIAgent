# 실험: `control_app` 통합 도구 (A/B)

**작성일**: 2026-04-16
**상태**: 실험 중 (legacy가 기본)

## 배경

기존 앱 제어는 3개의 도구로 분리되어 있었습니다.

- `send_app_command(appId, command, params)` — WebSocket으로 실행 중인 앱에 명령 전송
- `app_lifecycle(action, appName, ...)` — OS 레벨 실행/종료 (launch/terminate)
- `read_app_state(appId)` — 앱 상태 조회 (GET_STATE)
- `list_apps()` — 연결/설치 앱 목록

메인툴 슬롯을 과도하게 소비하고, AI가 "실행 후 명령 전송" 같은 2단계 사고를 해야 한다는 문제가 있었습니다. `send_app_command`는 앱이 켜져 있어야만 동작하므로 AI가 상태 체크/자동 실행 흐름을 매번 수행해야 했습니다.

## 가설

**명령 전송(send) 하나로 모든 앱 상호작용을 통일할 수 있다.**

- 앱이 꺼져 있으면 send가 **자동으로 실행 + 연결 대기** 후 명령 전달
- 종료는 약속된 `SHUTDOWN` 명령으로 앱이 스스로 처리 (프레임워크 레벨 예약 명령)
- 실행이라는 개념 자체를 AI의 시야에서 제거

## 설계

### 새 arm: `control_app`

[control_app.ts](control_app.ts) — 단일 도구 `control_app(app, command, params?, env?, args?)`

동작:
1. `isAppConnected(app)` 확인
2. 미연결이면:
   - `command === "SHUTDOWN"`: no-op 반환 (종료하려고 앱을 켜지 않음)
   - 그 외: `spawnApp` 호출 → `waitForAppConnection` (최대 15s, 300ms 간격 폴링)
3. 연결되면 `UserSocketHandler.commandApp` 호출

프레임워크 측 변경: [AppProtocolHandler.dart](../../ari-framework/plugin/lib/bridge/handler/AppProtocolHandler.dart)에 `SHUTDOWN` 예약 명령 처리 추가.

- `onShutdown` 콜백 (선택) — `false` 반환 시 종료 취소 (저장 중 등)
- `{ok, shuttingDown}` 응답 후 300ms 지연 → `exit(0)`
- `GET_STATE`와 동일 패턴으로 모든 앱이 자동으로 `SHUTDOWN` 지원

### 레거시 arm: `app_control`

[app_control.ts](app_control.ts) — `send_app_command` + `app_lifecycle`. 기존 동작 유지.

### 공통

[app_status.ts](app_status.ts) — `list_apps`, `read_app_state`. 양 arm 모두 로드.

## 전환 스위치

[app_control_mode.ts](app_control_mode.ts)

- 환경변수 `ARI_APP_CONTROL_MODE`
  - `legacy` (기본): `send_app_command` + `app_lifecycle`
  - `unified`: `control_app` 하나

분기 지점 2곳:
- [tools/index.ts](index.ts) — `BUILT_IN_TOOLS`의 `APP_TOOLSET`
- [services/tools/tool_registry.ts](../services/tools/tool_registry.ts) — 메인툴 이름

두 arm은 **상호 배타적**으로 로드됩니다.

## 실험 방법

```bash
# 기본 (legacy)
bun run ari-server

# 실험 arm
ARI_APP_CONTROL_MODE=unified bun run ari-server
```

각 arm에서 동일 시나리오를 AI에게 수행시키고 비교:

1. 꺼진 앱 제어 ("노트패드 열고 'hi' 입력해줘")
2. 켜진 앱 제어 ("현재 상태 알려줘")
3. 앱 종료 ("노트패드 꺼줘")
4. 이미 꺼진 앱 종료 ("노트패드 꺼줘")
5. 존재하지 않는 앱
6. 부팅이 느린 앱 (15초 초과)

비교 지표:
- AI 호출 횟수 (도구 콜 수)
- 사용자 발화에서 완료까지 지연
- 실패 케이스의 에러 메시지 명료성
- AI가 잘못 판단하는 케이스 빈도

## 확정 시 정리 체크리스트 (unified 승리 가정)

1. [app_control.ts](app_control.ts) 삭제
2. [app_control_mode.ts](app_control_mode.ts) 삭제
3. [tools/index.ts](index.ts)에서 `APP_CONTROL_TOOLS` / `APP_TOOLSET` 분기 제거 → `...CONTROL_APP_TOOLS`로 고정
4. [services/tools/tool_registry.ts](../services/tools/tool_registry.ts)에서 `APP_CONTROL_MAIN_TOOLS` 분기 제거 → `"control_app"`만 포함
5. `ari_app_guide` / `app_control` 등 관련 스킬 문서에서 `send_app_command`, `app_lifecycle` 언급을 `control_app`로 교체
6. 이 실험 문서(`EXPERIMENT_control_app.md`) 삭제 또는 "완료"로 이동

## 롤백 시 정리 (legacy 승리 가정)

1. [control_app.ts](control_app.ts) 삭제
2. [AppProtocolHandler.dart](../../ari-framework/plugin/lib/bridge/handler/AppProtocolHandler.dart)에서 `SHUTDOWN` 분기 및 `onShutdown` 필드 제거 (`dart:io` import도)
3. [app_control_mode.ts](app_control_mode.ts) 삭제
4. 분기 로직을 legacy로 고정
5. 이 문서 삭제

## 알려진 한계 / 주의

- **프리즈/무응답 앱**: `control_app`의 `SHUTDOWN`은 WS 기반이라 응답 없는 앱을 죽이지 못함. 필요하면 `execute_bash`로 OS 레벨 kill (fallback).
- **부팅 타임아웃**: 15초로 하드코딩. 느린 앱이 있으면 `LAUNCH_WAIT_TIMEOUT_MS` 조정 필요.
- **식별자 통일 가정**: `control_app`은 번들명 == WebSocket appId를 전제. 둘이 다른 앱이 있다면 별도 처리 필요.
- **SHUTDOWN 미구현 앱**: 프레임워크 레벨에서 처리하므로 모든 ARI 프레임워크 기반 앱은 자동 지원. 다만 프레임워크를 쓰지 않는 앱은 unknown command 에러 반환.
