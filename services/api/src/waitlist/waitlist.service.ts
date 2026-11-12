import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DateTime } from 'luxon';
import { config } from '../common/config';
import { PrismaService } from '../common/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

export interface WaitlistInput {
  clientId: string;
  serviceId: string;
  preferredFrom: string;
  preferredTo: string;
  fromMinute?: number;
  toMinute?: number;
  priority?: number;
}

@Injectable()
export class WaitlistService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: NotificationsService) {}

  async add(businessId: string, dto: WaitlistInput) {
    const [client, service] = await Promise.all([
      this.prisma.client.findFirst({ where: { id: dto.clientId, businessId } }),
      this.prisma.service.findFirst({ where: { id: dto.serviceId, businessId } }),
    ]);
    if (!client || !service) throw new NotFoundException('Client or service not found');
    if (dto.preferredTo < dto.preferredFrom) throw new BadRequestException('preferredTo before preferredFrom');
    return this.prisma.waitlistEntry.create({
      data: {
        businessId, clientId: dto.clientId, serviceId: dto.serviceId,
        preferredFrom: new Date(`${dto.preferredFrom}T00:00:00Z`), preferredTo: new Date(`${dto.preferredTo}T00:00:00Z`),
        fromMinute: dto.fromMinute ?? 0, toMinute: dto.toMinute ?? 1440, priority: dto.priority ?? 0,
      },
    });
  }

  list(businessId: string) {
    return this.prisma.waitlistEntry.findMany({
      where: { businessId, status: { in: ['WAITING', 'OFFERED'] } },
      include: { client: true, service: true },
      orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
    });
  }

  async remove(businessId: string, id: string) {
    const r = await this.prisma.waitlistEntry.updateMany({ where: { id, businessId }, data: { status: 'REMOVED' } });
    if (!r.count) throw new NotFoundException();
  }

  /**
   * Called when a slot is released. Offers it to the single best matching entry.
   * The conditional update (status WAITING -> OFFERED) guarantees one offer per entry even under races;
   * the eventual booking still goes through the normal conflict-checked booking path, so the slot
   * can never be confirmed for two clients.
   */
  async onSlotReleased(businessId: string, start: Date, end: Date) {
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    if (!business.waitlistEnabled) return null;
    const local = DateTime.fromJSDate(start, { zone: business.timezone });
    const date = new Date(`${local.toISODate()}T00:00:00Z`);
    const startMinute = local.hour * 60 + local.minute;
    const durationMin = (+end - +start) / 60_000;
    const candidates = await this.prisma.waitlistEntry.findMany({
      where: { businessId, status: 'WAITING', preferredFrom: { lte: date }, preferredTo: { gte: date }, fromMinute: { lte: startMinute }, toMinute: { gte: startMinute } },
      include: { service: true, client: true },
      orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
    });
    const match = candidates.find((c) => c.service.durationMinutes <= durationMin);
    if (!match) return null;
    const claimed = await this.prisma.waitlistEntry.updateMany({ where: { id: match.id, status: 'WAITING' }, data: { status: 'OFFERED' } });
    if (!claimed.count) return null;
    const recipient = match.client.phone ?? match.client.email;
    if (recipient) {
      await this.notifications.enqueue(this.prisma, {
        businessId, channel: match.client.phone ? 'SMS' : 'EMAIL', recipient, template: 'waitlist_offer',
        payload: { clientName: match.client.fullName, start: start.toISOString(), service: match.service.name, link: `${config.publicBookingBaseUrl}/${business.slug}` },
        dedupeKey: `waitlist:${match.id}:${start.toISOString()}`,
      });
    }
    return match.id;
  }
}
