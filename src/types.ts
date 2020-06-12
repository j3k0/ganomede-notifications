import { Message } from "./push-api/queue";

export interface NotificationPush {
  app: string;
  title: Array<string>;
  titleArgsTypes: Array<string>;
  message: Array<string>;
  messageArgsTypes: Array<string>;
};

export interface Notification {
  id: number;
  type: string;
  from: string;
  to: string;
  timestamp: number;
  data: object;
  push?: NotificationPush;
  secret?: string;
  translated?: Message;
};

export interface AuthUser {
};
