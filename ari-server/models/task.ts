import type { ScheduleSpec } from "./schedule_spec.js";

/**
 * 스케줄링된 작업 정보를 정의하는 모델
 */
export class Task {
  id: string;               // 고유 ID (Timestamp 등)
  prompt: string;           // 에이전트에게 전달할 명령 내용
  scheduleSpec?: ScheduleSpec; // 구조화된 스케줄 명세 (반복 작업용)
  label: string;            // 사용자에게 보여줄 이름
  agentId?: string;         // 어떤 아바타의 스케줄인지 기록 (기본: default)
  appId?: string;           // 어떤 앱에서 생성한 스케줄인지 기록
  isOneOff?: boolean;       // 1회성 스케줄 여부
  enabled: boolean;         // 활성화 여부
  timeout?: number;         // 태스크 최대 실행 시간 (초, 기본값: 120)
  startAt: string;          // 실행 시작 일시 (기본값: 생성 시각)
  endAt?: string;           // 실행 종료 일시 (기본값: null = 무한)
  createdAt: string;        // 생성 일시
  lastRunAt?: string;       // 마지막 실행 시각
  lastResult?: string;      // 마지막 실행 결과
  lastError?: string;       // 마지막 실행 오류
  // 대상 에이전트 세션에 주입할 페르소나 (sender-push 원칙의 저장본).
  // 생성자가 대상 앱을 알고 있으므로 그 시점에 함께 기록한다.
  persona?: string;
  avatarName?: string;
  // 위임 대상 도메인 에이전트 appId.
  // 지정되면 task 실행 시 PM 을 거치지 않고 해당 도메인에 forward.
  // 응답은 ari 채팅창에 ari-broadcast 로 표시.
  targetAppId?: string;

  constructor(data: any = {}) {
    this.id = data?.id || Date.now().toString();
    this.prompt = data?.prompt || "";
    this.scheduleSpec = data?.scheduleSpec;
    this.label = data?.label || "";
    this.agentId = data?.agentId || "default";
    this.appId = data?.appId;
    this.isOneOff = data?.isOneOff !== undefined ? data.isOneOff : false;
    this.enabled = data?.enabled !== undefined ? data.enabled : true;
    this.timeout = data?.timeout;
    this.startAt = data?.startAt || new Date().toISOString();
    this.endAt = data?.endAt;
    this.createdAt = data?.createdAt || new Date().toISOString();
    this.lastRunAt = data?.lastRunAt;
    this.lastResult = data?.lastResult;
    this.lastError = data?.lastError;
    this.persona = data?.persona;
    this.avatarName = data?.avatarName;
    this.targetAppId = data?.targetAppId;
  }

  static fromJson(jsonStr: string | any): Task {
    try {
      const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      return new Task(data || {});
    } catch {
      return new Task();
    }
  }
}
