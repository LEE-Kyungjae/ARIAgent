// Inter-agent forward 응답 대기 레지스트리.
// ARI 가 SARI 등 다른 앱 에이전트에게 자연어 지시(message)를 포워드하면,
// 대상 앱이 자기 쪽에서 세션을 돌려 /APP.PUSH 로 결과를 돌려준다. 그 시점까지
// 호출자 쪽 툴 실행은 여기 등록된 Promise 에 매달려 기다린다.
// - control_app 툴: registerForwardWaiter 로 대기자 등록
// - agent_session:  세션 완료/실패 시 resolve/reject 호출

interface ForwardWaiter {
  resolve: (text: string) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

const pendingForwards = new Map<string, ForwardWaiter>();

export function registerForwardWaiter(
  requestId: string,
  opts: { timeoutMs: number; timeoutMessage: string },
): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const timer = setTimeout(() => {
      if (pendingForwards.delete(requestId)) {
        reject(new Error(opts.timeoutMessage));
      }
    }, opts.timeoutMs);
    pendingForwards.set(requestId, { resolve, reject, timer });
  });
}

export function resolveForwardIfPending(
  requestId: string,
  responseText: string,
): boolean {
  const w = pendingForwards.get(requestId);
  if (!w) return false;
  pendingForwards.delete(requestId);
  clearTimeout(w.timer);
  w.resolve(responseText);
  return true;
}

export function rejectForwardIfPending(
  requestId: string,
  error: Error,
): boolean {
  const w = pendingForwards.get(requestId);
  if (!w) return false;
  pendingForwards.delete(requestId);
  clearTimeout(w.timer);
  w.reject(error);
  return true;
}
