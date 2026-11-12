import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DateTime } from 'luxon';
import { PrismaService } from '../common/prisma.service';
import { AvailabilityInput, computeAvailability, DayAvailability, freeGaps, Interval, isSlotAvailable, workingIntervals } from './engine';

type Db = PrismaService | Prisma.TransactionClient;

export interface AvailabilityQuery {
  businessId: string;
  fromDate: string;
  toDate: string;
  serviceIds: string[];
  employeeId?: string;
  locationId?: string;
  mode?: 'all' | 'compact';
  /** true for public online booking: applies min-notice and horizon rules */
  online: boolean;
  durationOverride?: number;
}

const ACTIVE = ['BOOKED', 'CONFIRMED', 'COMPLETED'] as const;

@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async loadContext(db: Db, businessId: string, employeeId: string, from: Date, to: Date, excludeAppointmentId?: string) {
    const [rules, exceptions, appts] = await Promise.all([
      db.workSchedule.findMany({ where: { businessId, employeeId } }),
      db.scheduleException.findMany({ where: { businessId, employeeId, date: { gte: new Date(+from - 2 * 86_400_000), lte: new Date(+to + 2 * 86_400_000) } } }),
      db.appointment.findMany({
        where: {
          businessId, employeeId, status: { in: [...ACTIVE] },
          startsAt: { lt: to }, endsAt: { gt: from },
          ...(excludeAppointmentId ? { id: { not: excludeAppointmentId } } : {}),
        },
        select: { startsAt: true, endsAt: true },
      }),
    ]);
    return {
      rules: rules.map((r) => ({ weekday: r.weekday, startMinute: r.startMinute, endMinute: r.endMinute, breakStartMinute: r.breakStartMinute, breakEndMinute: r.breakEndMinute, locationId: r.locationId })),
      overrides: exceptions.map((e) => ({ date: e.date.toISOString().slice(0, 10), isClosed: e.isClosed, startMinute: e.startMinute, endMinute: e.endMinute })),
      busy: appts.map((a) => ({ start: a.startsAt, end: a.endsAt })) as Interval[],
    };
  }

  async serviceTotals(db: Db, businessId: string, serviceIds: string[], onlineOnly: boolean) {
    if (serviceIds.length === 0) throw new BadRequestException('At least one service is required');
    const services = await db.service.findMany({ where: { businessId, id: { in: serviceIds }, isActive: true, ...(onlineOnly ? { onlineBookable: true } : {}) } });
    if (services.length !== new Set(serviceIds).size) throw new NotFoundException('Service not found');
    return {
      services,
      duration: services.reduce((s, x) => s + x.durationMinutes, 0),
      buffer: Math.max(...services.map((x) => x.bufferMinutes)),
      price: services.reduce((s, x) => s + x.priceMinor, 0),
      deposit: services.reduce((s, x) => s + x.depositMinor, 0),
    };
  }

  async resolveEmployee(db: Db, businessId: string, employeeId?: string) {
    const emp = await db.employee.findFirst({ where: { businessId, isActive: true, ...(employeeId ? { id: employeeId } : {}) }, orderBy: { createdAt: 'asc' } });
    if (!emp) throw new NotFoundException('Specialist not found');
    return emp;
  }

  async query(q: AvailabilityQuery): Promise<{ employeeId: string; durationMinutes: number; days: DayAvailability[] }> {
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: q.businessId } });
    const employee = await this.resolveEmployee(this.prisma, q.businessId, q.employeeId);
    const totals = q.serviceIds.length
      ? await this.serviceTotals(this.prisma, q.businessId, q.serviceIds, q.online)
      : { duration: q.durationOverride ?? 60, buffer: 0 };
    const duration = q.durationOverride ?? totals.duration;
    const from = DateTime.fromISO(q.fromDate, { zone: business.timezone }).minus({ days: 1 }).toJSDate();
    const to = DateTime.fromISO(q.toDate, { zone: business.timezone }).plus({ days: 2 }).toJSDate();
    const ctx = await this.loadContext(this.prisma, q.businessId, employee.id, from, to);
    const input: AvailabilityInput = {
      timezone: business.timezone,
      fromDate: q.fromDate,
      toDate: q.toDate,
      ...ctx,
      durationMinutes: duration,
      bufferMinutes: totals.buffer,
      stepMinutes: business.slotStepMinutes,
      now: new Date(),
      minNoticeMinutes: q.online ? business.minNoticeMinutes : 0,
      maxHorizonDays: q.online ? business.maxHorizonDays : undefined,
      locationId: q.locationId,
      mode: q.mode,
    };
    return { employeeId: employee.id, durationMinutes: duration, days: computeAvailability(input) };
  }

  async verifySlot(db: Db, args: { businessId: string; timezone: string; employeeId: string; start: Date; duration: number; buffer: number; step: number; minNotice: number; horizon?: number; locationId?: string }) {
    const ctx = await this.loadContext(db, args.businessId, args.employeeId, new Date(+args.start - 2 * 86_400_000), new Date(+args.start + 2 * 86_400_000));
    return isSlotAvailable({
      timezone: args.timezone, ...ctx, durationMinutes: args.duration, bufferMinutes: args.buffer, stepMinutes: args.step,
      now: new Date(), minNoticeMinutes: args.minNotice, maxHorizonDays: args.horizon, locationId: args.locationId,
    }, args.start);
  }

  /** Working hours + free gaps for one local day, for the day view. */
  async dayGaps(businessId: string, employeeId: string, date: string, timezone: string) {
    const from = DateTime.fromISO(date, { zone: timezone }).minus({ days: 1 }).toJSDate();
    const to = DateTime.fromISO(date, { zone: timezone }).plus({ days: 2 }).toJSDate();
    const ctx = await this.loadContext(this.prisma, businessId, employeeId, from, to);
    const working = workingIntervals(date, { timezone, rules: ctx.rules, overrides: ctx.overrides });
    return { working, gaps: freeGaps(working, ctx.busy) };
  }
}
