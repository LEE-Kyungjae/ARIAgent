import { router } from "../system/router.js";
import {
  addScheduledTask,
  removeScheduledTask,
  refreshScheduler,
} from "../services/tasks/index.js";
import { runScheduledTask } from "../services/tasks/run_task.js";
import { notifyTaskResult } from "../protocol/task.js";
import { logger } from "../infra/logger.js";
import { appendChatLog } from "../repositories/chat_log_repository.js";
import {
  getTasks,
  saveTasks,
  toggleTask,
  findTask,
} from "../repositories/task_repository.js";
import { Task } from "../models/task.js";

router.on("/TASKS", async (ctx, params) => {
  ctx.send("/TASKS", { ok: true, data: { tasks: getTasks() } });
});

router.on("/TASKS.SYNC", async (ctx, params) => {
  const tasks = params.tasks as Task[];
  saveTasks(tasks);
  logger.info(`📋 tasks.json 동기화: ${tasks.length}개`);
  await refreshScheduler();
  ctx.send("/TASKS.SYNC", { ok: true, data: { success: true } });
});

// ── 개별 CRUD API ──

router.on("/TASKS.ADD", async (ctx, params) => {
  const data = await addScheduledTask(params);
  ctx.send("/TASKS.ADD", { ok: true, data });
});

router.on("/TASKS.DELETE", async (ctx, params) => {
  const data = await removeScheduledTask(params);
  ctx.send("/TASKS.DELETE", { ok: true, data });
});

router.on("/TASKS.TOGGLE", async (ctx, params) => {
  const taskId = params.taskId as string;
  const task = toggleTask(taskId);
  if (!task) {
    logger.warn(`⚠️ Task 토글 실패: ID ${taskId} 없음`);
    ctx.send("/TASKS.TOGGLE", { ok: true, data: { task: null } });
    return;
  }
  logger.info(`🔄 Task 토글: "${task.label}" → ${task.enabled ? "활성" : "비활성"}`);
  await refreshScheduler();
  ctx.send("/TASKS.TOGGLE", { ok: true, data: { task } });
});

router.on("/TASKS.RUN", async (ctx, params) => {
  const taskId = params.taskId as string;
  const task = findTask(taskId);
  if (!task) {
    throw new Error(`Task ID ${taskId}를 찾을 수 없음`);
  }
  await runScheduledTask(task);
  ctx.send("/TASKS.RUN", { ok: true, data: { taskId: task.id, started: true } });
});

// 크론 작업(run_task.ts)으로부터 결과를 받아 모든 클라이언트에게 브로드캐스트
router.on("/TASKS.NOTIFY_RESULT", async (ctx, params) => {
  logger.info(`📡 Inbound: /TASKS.NOTIFY_RESULT from client [${ctx.uuid}] for [${params.label || "unknown"}]`);

  const taskId = params.taskId as string | undefined;
  const matchedTask = taskId
    ? getTasks().find((task) => task.id === taskId)
    : undefined;
  const agentId =
    (params.agentId as string | undefined) ||
    matchedTask?.agentId ||
    "default";
  const appId =
    (params.appId as string | undefined) || matchedTask?.appId;

  // 브로드캐스트 데이터 구성
  const broadcastData = {
    taskId: params.taskId,
    requestId: params.requestId,
    agentId,
    label: params.label,
    result: params.result,
    executedAt: new Date().toISOString(),
  };

  // 태스크 결과 저장
  appendChatLog(appId, agentId, {
    type: 'task',
    taskId: params.taskId,
    label: params.label,
    result: params.result
  });

  // /TASK_RESULT 채널로 모든 클라이언트에게 전송 (MQ의 Publish 역할)
  notifyTaskResult(broadcastData);

  logger.info(`📡 MQ: Broadcaster finished for [${params.label || "unknown"}]`);
  ctx.send("/TASKS.NOTIFY_RESULT", { ok: true });
});
