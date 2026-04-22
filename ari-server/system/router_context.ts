export interface RouterContext {
  uuid: string;
  appId?: string;
  send(cmd: string, data: any): void;
}
