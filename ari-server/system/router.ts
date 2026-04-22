import { RouterContext } from "../models/router_context.js";
import { log } from "../infra/logger.js";
import { validator } from "./validator.js";

type Listener = (ctx: RouterContext, value: any) => void | Promise<void>;

class Router {
  private events: { [key: string]: Listener[] } = {};

  public on(type: string, listener: Listener): void {
    if (!this.events[type]) {
      this.events[type] = [];
    }
    this.events[type].push(listener);
  }

  public once(type: string, listener: Listener): void {
    const wrapper: Listener = (ws, value) => {
      this.off(type, wrapper);
      return listener(ws, value);
    };
    this.on(type, wrapper);
  }

  public off(type: string, listener?: Listener): void {
    if (!this.events[type]) return;
    if (!listener) {
      delete this.events[type];
      return;
    }
    this.events[type] = this.events[type].filter((l) => l !== listener);
  }

  public alias(oldtype: string, type: string): void {
    if (this.events[oldtype]) {
      this.events[oldtype].forEach((listener) => {
        if (!this.events[type]) {
          this.events[type] = [];
        }
        this.events[type].push(listener);
      });
    }
  }

  public emit(type: string, ctx: RouterContext, value: any): boolean {
    if (this.events[type] && this.events[type].length > 0) {
      this.events[type].forEach((listener) => {
        Promise.resolve(listener(ctx, value)).catch((err) => {
          log.error(`router listener error [${type}]: ${err}`);
        });
      });
      return true;
    }
    return false;
  }

  public async parse(ctx: RouterContext, request: string): Promise<void> {
    // \r\n 을 \n으로 통일
    request = request.replace(/\r\n/g, "\n");
    const lines = request.split("\n");

    for (const line of lines) {
      const item = line.trim();
      if (!item) continue;

      let cmd = "";
      let value = "{}";
      const cmdIndex = item.indexOf(" ");
      if (cmdIndex < 0) {
        cmd = item;
      } else {
        cmd = item.slice(0, cmdIndex);
        value = item.slice(cmdIndex + 1);
      }

      let handled = false;
      if (validator.isJSON(value)) {
        const param = JSON.parse(value);
        param.cmd = cmd; // 추가 정보
        const fullType = param.requestId ? `${cmd.toUpperCase()}:${param.requestId}` : cmd.toUpperCase();

        handled = this.emit(fullType, ctx, param);

        if (param.requestId) {
          // requestId가 있으면 기본 타입으로도 emit (호환성)
          const baseHandled = this.emit(cmd.toUpperCase(), ctx, param);
          handled = handled || baseHandled;
        }
      } else {
        const values = item.split(" ");
        values.shift(); // 첫번째 요소(cmd) 제거
        handled = this.emit(cmd.toUpperCase(), ctx, values);
      }

      if (!handled && cmd.startsWith("/")) {
        log.warn(`[Router] Unhandled command: ${cmd} from ${ctx.uuid} (${ctx.appId || "unknown"})`);
        ctx.send(cmd, { ok: false, code: 0, message: "no cmd", data: {} });
      }
    }
  }
}

export const router = new Router();
