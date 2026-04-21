import { Task } from "../../models/task.js";
import { getTasks, saveTasks } from "../../repositories/task_repository.js";
import { executeAgentRequest } from "../agent/index.js";
import { UserSocketHandler } from "../../system/ws.js";
import { appendChatLog } from "../../repositories/chat_log_repository.js";
import { logger } from "../../infra/logger.js";
import { t } from "../../infra/i18n.js";

const DEFAULT_TIMEOUT_SEC = 120;

// ──────────────────────────────────────────────────────────────────────────────
// Main entry
// ──────────────────────────────────────────────────────────────────────────────

type RunScheduledTaskOptions = {
  exitProcess?: boolean;
};

export async function runScheduledTask(
  taskOrId: Task | string,
  options: RunScheduledTaskOptions = {},
): Promise<void> {
  // Task 객체 또는 ID 문자열 모두 수용
  let task: Task | undefined;
  if (typeof taskOrId === "string") {
    task = getTasks().find((t: Task) => t.id === taskOrId);
    if (!task) throw new Error(`작업 ID ${taskOrId}를 찾을 수 없음`);
  } else {
    task = taskOrId;
  }

  logger.info(`🔔 작업 실행 시작: ${task.id} (${task.label})`);

  if (!task.enabled) {
    logger.info("⏸️ 비활성 작업 — 스킵");
    return;
  }

  const now = new Date();
  if (new Date(task.startAt) > now) {
    logger.info(`⏳ 시작일 전 (${task.startAt}) — 스킵`);
    return;
  }
  if (task.endAt && new Date(task.endAt) < now) {
    logger.info(`⏰ 종료일 지남 (${task.endAt}) — 스킵`);
    return;
  }

  const agentId = task.agentId || "default";
  const noticeId = `notice-task-start-${task.id}-${Date.now()}`;
  const noticeMessage = t("task.notice.started", { label: task.label });

  appendChatLog(task.appId, agentId, {
    type: "notice",
    message: noticeMessage,
    noticeId,
  });
  UserSocketHandler.send({ appId: "ari" }, "/APP.NOTICE", {
    noticeId,
    agentId,
    message: noticeMessage,
  });

  const timeoutMs = (task.timeout ?? DEFAULT_TIMEOUT_SEC) * 1000;

  // ── AI 에이전트 직접 호출 ────────────────────────────────────────────────
  try {
    const runRequestId = `${task.id}-${Date.now()}`;
    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(
        () =>
          reject(
            new Error(
              t("task.error.timeout", {
                seconds: task.timeout ?? DEFAULT_TIMEOUT_SEC,
              }),
            ),
          ),
        timeoutMs,
      ),
    );

    const result = await Promise.race([
      executeAgentRequest({
        message: task.prompt,
        requestId: runRequestId,
        agentId,
        appId: task.appId,
        persona: task.persona,
        avatarName: task.avatarName,
        waitForCompletion: true,
      }),
      timeoutPromise,
    ]);

    if (result.status === "cancelled") {
      throw new Error(t("task.error.cancelled"));
    }

    const responseText = result.responseText || t("task.response.empty");
    logger.info(`✅ 완료: ${responseText.substring(0, 80)}...`);
    const executedAt = new Date().toISOString();

    persistTaskResult(task.id, {
      lastRunAt: executedAt,
      lastResult: responseText,
      lastError: undefined,
    });

    UserSocketHandler.send({ appId: "ari" }, "/TASK_RESULT", {
      taskId: task.id,
      requestId: runRequestId,
      agentId,
      label: task.label,
      result: responseText,
      executedAt,
    });

  } catch (err: any) {
    logger.error(`❌ 실행 오류: ${err.message}`);
    persistTaskResult(task.id, {
      lastRunAt: new Date().toISOString(),
      lastError: err.message,
    });
  }

  if (options.exitProcess) process.exit(0);
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

function persistTaskResult(
  taskId: string,
  data: { lastRunAt: string; lastResult?: string; lastError?: string },
): void {
  const tasks = getTasks();
  const index = tasks.findIndex((t) => t.id === taskId);
  if (index === -1) return;

  tasks[index].lastRunAt = data.lastRunAt;
  if (data.lastResult !== undefined) tasks[index].lastResult = data.lastResult;
  if (data.lastError !== undefined) tasks[index].lastError = data.lastError;
  else delete tasks[index].lastError;

  saveTasks(tasks);
}

// ──────────────────────────────────────────────────────────────────────────────
// CLI entry (하위 호환 — 직접 실행 시)
// ──────────────────────────────────────────────────────────────────────────────

function isDirectRunTaskEntry(): boolean {
  const entryFile = process.argv[1];
  return entryFile ? /(?:^|[\\/])run_task\.(?:[cm]?js|ts)$/.test(entryFile) : false;
}

if (isDirectRunTaskEntry()) {
  const taskId = process.argv[2];
  if (!taskId) {
    logger.info("Usage: node run_task.js <task_id>");
    process.exit(1);
  }
  runScheduledTask(taskId, { exitProcess: true }).catch((err) => {
    logger.error(err);
    process.exit(1);
  });
}
