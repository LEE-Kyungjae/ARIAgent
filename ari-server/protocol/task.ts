import { UserSocketHandler } from "../system/ws.js";

/**
 * /TASK* 아웃바운드 프로토콜.
 * 연결된 모든 앱에 브로드캐스트 — 클라이언트가 자기 appId 로 필터링한다
 * (예: SARI 는 AriTaskProvider.tasksForApp('sari') 로 추림).
 * ari 전용으로 한정하면 도메인 앱(SARI 등)이 자기 스케줄을 실시간으로 못 봄.
 */

function broadcastToAllApps(cmd: string, data: any): void {
  for (const appId of UserSocketHandler.getConnectedAppIds()) {
    UserSocketHandler.send({ appId }, cmd, data);
  }
}

/**
 * 연결된 전 앱에 태스크 목록 갱신을 알림.
 */
export const notifyTasksUpdated = (tasks: any[]): void => {
  broadcastToAllApps("/TASKS.UPDATED", { tasks });
};

/**
 * 연결된 전 앱에 태스크 실행 결과 브로드캐스트.
 */
export const notifyTaskResult = (payload: {
  taskId?: string;
  requestId?: string;
  agentId: string;
  label?: string;
  result?: string;
  executedAt: string;
}): void => {
  broadcastToAllApps("/TASK_RESULT", payload);
};
