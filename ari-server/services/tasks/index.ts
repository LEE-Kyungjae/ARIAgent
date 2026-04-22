import { Task } from "../../models/task.js";
import {
  initTasksFileIfMissing,
  getTasks,
  addTask,
  deleteTask,
} from "../../repositories/task_repository.js";
import { logger } from "../../infra/logger.js";
import { getTaskScheduler } from "./scheduler/runtime.js";
import { notifyTasksUpdated } from "../../protocol/task.js";

// 초기 다운 방지: tasks.json이 없으면 빈 배열로 자동 생성
initTasksFileIfMissing();

// ── 스케줄러 자동 갱신 + 모든 클라이언트에 변경 알림 ──
export async function refreshScheduler(): Promise<void> {
  const scheduler = getTaskScheduler();
  if (!scheduler) {
    logger.warn("[LocalTaskScheduler] Sync requested before scheduler initialization.");
    return;
  }

  const result = await scheduler.restoreFromDisk();
  logger.info(
    `[LocalTaskScheduler] Sync complete: ${result.restored.length} restored, ${result.failed.length} failed.`,
  );
  notifyTasksUpdated(getTasks());
}

// ── 공유 도메인 오퍼레이션 (router + tools/schedule.ts) ──

export async function addScheduledTask(params: Record<string, unknown>): Promise<{ task: Task }> {
  const id = Date.now().toString();
  const now = new Date().toISOString();
  const startAt = (params.startAt as string) || now;

  // 1회성 태스크: endAt = startAt + 59초 (별도 지정이 없으면 자동 설정)
  const endAt: string | undefined =
    (params.endAt as string | undefined) ??
    (params.isOneOff ? new Date(new Date(startAt).getTime() + 59_000).toISOString() : undefined);

  const task = new Task({
    id,
    prompt: params.prompt,
    scheduleSpec: params.scheduleSpec,
    label: params.label,
    agentId: params.agentId || "default",
    appId: params.appId,
    isOneOff: params.isOneOff || false,
    enabled: true,
    timeout: params.timeout,
    startAt,
    endAt,
    createdAt: now,
    // Sender-push 원칙: 태스크 생성자가 대상 세션의 페르소나/아바타명을
    // 알고 있다면 함께 저장한다. 실행 시점에 executeAgentRequest 로 전달.
    persona: params.persona,
    avatarName: params.avatarName,
    // 명시적 도메인 위임 — 실행 시 PM 우회.
    targetAppId: params.targetAppId,
  });

  addTask(task);
  logger.info(`➕ Task 추가: "${task.label}"`);

  await refreshScheduler();
  return { task };
}

export async function removeScheduledTask(params: Record<string, unknown>): Promise<{ success: boolean }> {
  const taskId = params.taskId as string;
  if (!deleteTask(taskId)) {
    logger.warn(`⚠️ Task 삭제 실패: ID ${taskId} 없음`);
    return { success: false };
  }
  logger.info(`🗑️ Task 삭제: ${taskId}`);

  await refreshScheduler();
  return { success: true };
}
