import { Logger } from '@nestjs/common';
import { NotificationChannel } from '@prisma/client';

export interface DeliveryAdapter {
  readonly name: string;
  send(msg: { channel: NotificationChannel; recipient: string; template: string; payload: unknown }): Promise<{ providerId: string }>;
}

/**
 * Sandbox adapter: records deliveries in memory/logs and NEVER contacts a real provider.
 * Production providers (FCM, SMTP, SMS, WhatsApp Business Cloud API) are not wired because
 * no credentials / Meta approval are available — status: BLOCKED (see docs/known-limitations.md).
 */
export class SandboxAdapter implements DeliveryAdapter {
  readonly name = 'sandbox';
  readonly sent: { channel: NotificationChannel; recipient: string; template: string; payload: unknown }[] = [];
  private readonly log = new Logger('SandboxNotifications');
  failNext = 0;
  async send(msg: { channel: NotificationChannel; recipient: string; template: string; payload: unknown }) {
    if (this.failNext > 0) { this.failNext--; throw new Error('sandbox simulated failure'); }
    this.sent.push(msg);
    if (process.env.NODE_ENV !== 'test') this.log.log(`[${msg.channel}] -> ${msg.recipient}: ${msg.template}`);
    return { providerId: `sandbox-${this.sent.length}` };
  }
}

export const DELIVERY_ADAPTER = Symbol('DELIVERY_ADAPTER');
