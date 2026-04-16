/**
 * 앱 제어 도구 A/B 스위치
 *
 * - "legacy" (기본값): `app_control.ts`의 `send_app_command` + `app_lifecycle` 사용
 * - "unified": `control_app.ts`의 단일 `control_app` 도구 사용 (SHUTDOWN 명령 + 자동 실행)
 *
 * 환경변수 `ARI_APP_CONTROL_MODE`로 전환합니다. (e.g. `ARI_APP_CONTROL_MODE=unified`)
 *
 * A/B 테스트 종료 후 `unified`로 확정되면 `app_control.ts`와 이 파일을 삭제하고
 * `tools/index.ts` / `services/tools/tool_registry.ts`에서 분기 로직을 제거하면 됩니다.
 */
export type AppControlMode = "legacy" | "unified";

export const APP_CONTROL_MODE: AppControlMode =
  process.env.ARI_APP_CONTROL_MODE === "legacy" ? "legacy" : "unified";
