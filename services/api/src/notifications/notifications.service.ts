import { Inject, Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { NotificationChannel, Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { DELIVERY_ADAPTER, DeliveryAdapter } from './adapters';

export const MAX_ATTEMPTS = 5;

/**
 * Transactional outbox for notifications. Jobs are de-duplicated by `dedupeKey`
 * (unique index) so retries / repeated triggers never double-send. A poller claims due jobs
 * with FOR UPDATE SKIP LOCKED so multiple API instances can run workers safely.
 * After MAX_ATTEMPTS failures a job is parked as FAILED (dead letter).
 */
@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  constructor(private readonly prisma: PrismaService, @Inject(DELIVERY_ADAPTER) private readonly adapter: DeliveryAdapter) {}

  onModuleInit() {
    if (process.env.NODE_ENV !== 'test' && process.env.NOTIFICATIONS_WORKER !== 'off') {
      this.timer = setInterval(() => void this.processDue().catch(() => undefined), 15_000);
    }
  }
  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async enqueue(
    db: PrismaService | Prisma.TransactionClient,
    job: { businessId: string; channel: NotificationChannel; recipient: string; template: string; payload: Prisma.InputJsonValue; dedupeKey: string; scheduledFor?: Date },
  ) {
    await db.notificationJob.upsert({
      where: { dedupeKey: job.dedupeKey },
      create: { ...job, scheduledFor: job.scheduledFor ?? new Date() },
      update: {},
    });
  }

  async processDue(limit = 50): Promise<{ sent: number; failed: number }> {
    const claimed = await this.prisma.$queryRaw<{ id: string }[]>`
      UPDATE notification_jobs SET attempts = attempts + 1
      WHERE id IN (
        SELECT id FROM notification_jobs
        WHERE status = 'QUEUED' AND "scheduledFor" <= now()
        ORDER BY "scheduledFor" LIMIT ${limit} FOR UPDATE SKIP LOCKED
      ) RETURNING id`;
    let sent = 0, failed = 0;
    for (const { id } of claimed) {
      const job = await this.prisma.notificationJob.findUniqueOrThrow({ where: { id } });
      try {
        await this.adapter.send({ channel: job.channel, recipient: job.recipient, template: job.template, payload: job.payload });
        await this.prisma.notificationJob.update({ where: { id }, data: { status: 'SENT', sentAt: new Date(), lastError: null } });
        sent++;
      } catch (e) {
        const dead = job.attempts >= MAX_ATTEMPTS;
        await this.prisma.notificationJob.update({
          where: { id },
          data: {
            status: dead ? 'FAILED' : 'QUEUED',
            lastError: (e as Error).message.slice(0, 500),
            // exponential backoff: 1, 2, 4, 8 min
            scheduledFor: new Date(Date.now() + 60_000 * 2 ** (job.attempts - 1)),
          },
        });
        failed++;
      }
    }
    return { sent, failed };
  }

  list(businessId: string) {
    return this.prisma.notificationJob.findMany({ where: { businessId }, orderBy: { createdAt: 'desc' }, take: 100 });
  }
}
