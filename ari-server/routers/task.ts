import { router } from "../system/router.js";
import { handleGetTasksWs, handleTasksSyncWs, handleTasksCrontabWs, handleAddTaskWs, handleDeleteTaskWs, handleToggleTaskWs, handleRunTaskWs } from "../services/task.js";
import { notifyTaskResult } from "../protocol/task.js";
import { logger } from "../infra/logger.js";
import { appendChatLog } from "../repositories/chat_log_repository.js";
import { getTasks } from "../repositories/task_repository.js";

router.on("/TASKS", async (ctx, params) => {
  const data = await handleGetTasksWs();
  ctx.send("/TASKS", { ok: true, data: data });
});

router.on("/TASKS.SYNC", async (ctx, params) => {
  await handleTasksSyncWs(params);
  ctx.send("/TASKS.SYNC", { ok: true, data: { success: true } });
});

router.on("/TASKS.CRONTAB", async (ctx, params) => {
  await handleTasksCrontabWs(params);
  ctx.send("/TASKS.CRONTAB", { ok: true, data: { success: true } });
});

// ── 개별 CRUD API ──

router.on("/TASKS.ADD", async (ctx, params) => {
  const data = await handleAddTaskWs(params);
  ctx.send("/TASKS.ADD", { ok: true, data });
});

router.on("/TASKS.DELETE", async (ctx, params) => {
  const data = await handleDeleteTaskWs(params);
  ctx.send("/TASKS.DELETE", { ok: true, data });
});

router.on("/TASKS.TOGGLE", async (ctx, params) => {
  const data = await handleToggleTaskWs(params);
  ctx.send("/TASKS.TOGGLE", { ok: true, data });
});

router.on("/TASKS.RUN", async (ctx, params) => {
  const data = await handleRunTaskWs(params);
  ctx.send("/TASKS.RUN", { ok: true, data });
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
