import { UserSocketHandler } from "../system/ws.js";

/**
 * /TASK* 아웃바운드 프로토콜. ari 대시보드 브로드캐스트 전용.
 */

/**
 * ari 에게 태스크 목록 갱신을 알림.
 */
export const notifyTasksUpdated = (tasks: any[]): void => {
  UserSocketHandler.send({ appId: "ari" }, "/TASKS.UPDATED", { tasks });
};

/**
 * ari 에게 태스크 실행 결과 브로드캐스트.
 */
export const notifyTaskResult = (payload: {
  taskId?: string;
  requestId?: string;
  agentId: string;
  label?: string;
  result?: string;
  executedAt: string;
}): void => {
  UserSocketHandler.send({ appId: "ari" }, "/TASK_RESULT", payload);
};
