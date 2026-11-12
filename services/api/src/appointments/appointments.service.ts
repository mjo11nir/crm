import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AppointmentSource, AppointmentStatus, Prisma } from '@prisma/client';
import { DateTime } from 'luxon';
import { AvailabilityService } from '../availability/availability.service';
import { workingIntervals } from '../availability/engine';
import { AuditService } from '../common/audit.service';
import { parseLocalDate } from '../common/dates';
import { isOverlapViolation, SlotTakenException } from '../common/errors';
import { applyPercentDiscount, remainingBalance } from '../common/money';
import { PrismaService } from '../common/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WaitlistService } from '../waitlist/waitlist.service';

export interface CreateAppointmentInput {
  clientId?: string;
  serviceIds: string[];
  employeeId?: string;
  locationId?: string;
  startsAt: string; // ISO instant
  durationMinutes?: number;
  discountPercent?: number;
  notes?: string;
  /** staff may book outside working hours explicitly */
  allowOutsideHours?: boolean;
  recurrence?: { everyWeeks: number; count: number };
}

export interface UpdateAppointmentInput {
  version: number;
  startsAt?: string;
  durationMinutes?: number;
  employeeId?: string;
  locationId?: string;
  clientId?: string | null;
  serviceIds?: string[];
  discountPercent?: number;
  notes?: string;
  allowOutsideHours?: boolean;
}

/**
 * Serialises booking writes per employee for the rest of the transaction. Without it, concurrent
 * inserts checked by the GiST exclusion constraint can deadlock (40P01). The constraint stays as
 * the final correctness guard; the lock makes contention resolve cleanly as 409 SLOT_TAKEN.
 */
async function lockEmployee(db: Prisma.TransactionClient, employeeId: string) {
  await db.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${employeeId}, 0))`;
}

const ACTIVE: AppointmentStatus[] = ['BOOKED', 'CONFIRMED', 'COMPLETED'];

/** Allowed status transitions. */
export const TRANSITIONS: Record<AppointmentStatus, AppointmentStatus[]> = {
  BOOKED: ['CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'],
  CONFIRMED: ['COMPLETED', 'CANCELLED', 'NO_SHOW', 'BOOKED'],
  COMPLETED: ['BOOKED'], // undo completion
  CANCELLED: [],
  NO_SHOW: ['BOOKED'],
};

const include = { client: true, services: true, payments: true, location: true, employee: true } satisfies Prisma.AppointmentInclude;
export type AppointmentWithRelations = Prisma.AppointmentGetPayload<{ include: typeof include }>;

@Injectable()
export class AppointmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: AvailabilityService,
    private readonly notifications: NotificationsService,
    private readonly waitlist: WaitlistService,
    private readonly audit: AuditService,
  ) {}

  present(a: AppointmentWithRelations) {
    const net = a.priceMinor - a.discountMinor;
    return { ...a, netPriceMinor: net, balanceMinor: remainingBalance(net, a.payments) };
  }

  async range(businessId: string, fromDate: string, toDate: string, opts: { employeeId?: string; q?: string; status?: AppointmentStatus } = {}) {
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    const from = parseLocalDate(fromDate, business.timezone);
    const to = parseLocalDate(toDate, business.timezone).plus({ days: 1 });
    if (to.diff(from, 'days').days > 400) throw new BadRequestException('Range too large');
    const where: Prisma.AppointmentWhereInput = {
      businessId,
      startsAt: { gte: from.toJSDate(), lt: to.toJSDate() },
      ...(opts.employeeId ? { employeeId: opts.employeeId } : {}),
      ...(opts.status ? { status: opts.status } : {}),
      ...(opts.q ? { OR: [{ client: { fullName: { contains: opts.q, mode: 'insensitive' } } }, { services: { some: { nameSnapshot: { contains: opts.q, mode: 'insensitive' } } } }] } : {}),
    };
    const items = await this.prisma.appointment.findMany({ where, include, orderBy: { startsAt: 'asc' } });
    return items.map((a) => this.present(a));
  }

  /** Day view: appointments, free gaps inside working hours and the day's revenue. */
  async day(businessId: string, date: string, employeeId?: string) {
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    parseLocalDate(date, business.timezone);
    const employee = await this.availability.resolveEmployee(this.prisma, businessId, employeeId);
    const appointments = await this.range(businessId, date, date, { employeeId: employee.id });
    const { working, gaps } = await this.availability.dayGaps(businessId, employee.id, date, business.timezone);
    const revenueMinor = appointments.filter((a) => ACTIVE.includes(a.status)).reduce((s, a) => s + a.netPriceMinor, 0);
    return {
      date,
      timezone: business.timezone,
      currency: business.currency,
      employeeId: employee.id,
      working: working.map((w) => ({ start: w.start, end: w.end })),
      freeGaps: gaps.map((g) => ({ start: g.start, end: g.end, minutes: Math.round((+g.end - +g.start) / 60_000) })),
      appointments,
      revenueMinor,
    };
  }

  /** Month overview: per-day count of active appointments (calendar dots). */
  async monthDots(businessId: string, fromDate: string, toDate: string) {
    const items = await this.range(businessId, fromDate, toDate);
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    const days: Record<string, { total: number; online: number }> = {};
    for (const a of items) {
      if (!ACTIVE.includes(a.status)) continue;
      const d = DateTime.fromJSDate(a.startsAt, { zone: business.timezone }).toISODate()!;
      days[d] ??= { total: 0, online: 0 };
      days[d].total++;
      if (a.source === 'ONLINE') days[d].online++;
    }
    return days;
  }

  async get(businessId: string, id: string) {
    const a = await this.prisma.appointment.findFirst({ where: { id, businessId }, include: { ...include, history: { orderBy: { createdAt: 'asc' } } } });
    if (!a) throw new NotFoundException('Appointment not found');
    return { ...this.present(a), history: a.history };
  }

  async create(businessId: string, userId: string | null, input: CreateAppointmentInput, source: AppointmentSource = 'STAFF') {
    const occurrences = input.recurrence ? Math.min(Math.max(input.recurrence.count, 1), 52) : 1;
    const everyWeeks = input.recurrence?.everyWeeks ?? 1;
    if (everyWeeks < 1 || everyWeeks > 12) throw new BadRequestException('everyWeeks must be 1..12');
    const first = new Date(input.startsAt);
    if (isNaN(+first)) throw new BadRequestException('Invalid startsAt');
    const business = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    const created: ReturnType<AppointmentsService['present']>[] = [];
    const conflicts: string[] = [];
    for (let i = 0; i < occurrences; i++) {
      // recurrence in local wall-clock time (stable across DST)
      const start = DateTime.fromJSDate(first, { zone: business.timezone }).plus({ weeks: i * everyWeeks }).toJSDate();
      try {
        created.push(await this.createOne(businessId, userId, { ...input, startsAt: start.toISOString() }, source));
      } catch (e) {
        if (occurrences > 1 && e instanceof ConflictException) { conflicts.push(start.toISOString()); continue; }
        throw e;
      }
    }
    return occurrences > 1 ? { created, conflicts } : created[0];
  }

  /**
   * Creates one appointment inside a transaction. Concurrency safety is guaranteed by the
   * `appointments_no_overlap` exclusion constraint: if two requests race for the same employee/time
   * one insert fails with exclusion_violation, which we translate to 409 SLOT_TAKEN.
   */
  async createOne(businessId: string, userId: string | null, input: CreateAppointmentInput, source: AppointmentSource, tx?: Prisma.TransactionClient) {
    const run = async (db: Prisma.TransactionClient) => {
      const business = await db.business.findUniqueOrThrow({ where: { id: businessId } });
      const totals = await this.availability.serviceTotals(db, businessId, input.serviceIds, source === 'ONLINE');
      const employee = await this.availability.resolveEmployee(db, businessId, input.employeeId);
      await lockEmployee(db, employee.id);
      const location = await this.resolveLocation(db, businessId, input.locationId);
      let client = null;
      if (input.clientId) {
        client = await db.client.findFirst({ where: { id: input.clientId, businessId } });
        if (!client) throw new NotFoundException('Client not found');
      }
      const duration = input.durationMinutes ?? totals.duration;
      if (duration < 5 || duration > 1440) throw new BadRequestException('Invalid duration');
      const startsAt = new Date(input.startsAt);
      const endsAt = new Date(+startsAt + duration * 60_000);
      if (source === 'ONLINE' || !input.allowOutsideHours) {
        const ok = await this.availability.verifySlot(db, {
          businessId, timezone: business.timezone, employeeId: employee.id, start: startsAt, duration,
          buffer: source === 'ONLINE' ? totals.buffer : 0,
          step: source === 'ONLINE' ? business.slotStepMinutes : 5,
          minNotice: source === 'ONLINE' ? business.minNoticeMinutes : -525_600,
          horizon: source === 'ONLINE' ? business.maxHorizonDays : undefined,
          locationId: location.id,
        });
        if (!ok) throw new SlotTakenException();
      }
      const discountPercent = input.discountPercent ?? client?.discountPercent ?? 0;
      const { discount } = applyPercentDiscount(totals.price, discountPercent);
      const status: AppointmentStatus = 'BOOKED';
      const appt = await db.appointment.create({
        data: {
          businessId, clientId: client?.id, employeeId: employee.id, locationId: location.id, startsAt, endsAt, status, source,
          priceMinor: totals.price, discountMinor: discount, notes: input.notes,
          services: { create: totals.services.map((s) => ({ serviceId: s.id, nameSnapshot: s.name, durationMinutes: s.durationMinutes, priceMinor: s.priceMinor })) },
          history: { create: { toStatus: status, changedBy: userId } },
        },
        include,
      });
      if (client) await this.scheduleClientNotifications(db, businessId, appt.id, client, startsAt, totals.services.map((s) => s.name).join(', '));
      return appt;
    };
    try {
      const appt = tx ? await run(tx) : await this.prisma.$transaction(run);
      if (!tx) await this.audit.log(businessId, userId, 'create', 'appointment', appt.id);
      return this.present(appt);
    } catch (e) {
      if (isOverlapViolation(e)) throw new SlotTakenException();
      throw e;
    }
  }

  async update(businessId: string, userId: string, id: string, input: UpdateAppointmentInput) {
    try {
      const updated = await this.prisma.$transaction(async (db) => {
        const existing = await db.appointment.findFirst({ where: { id, businessId }, include: { services: true } });
        if (!existing) throw new NotFoundException('Appointment not found');
        if (existing.version !== input.version) {
          throw new ConflictException({ code: 'VERSION_CONFLICT', message: 'Appointment was modified by someone else', currentVersion: existing.version });
        }
        if (existing.status === 'CANCELLED') throw new BadRequestException('Cancelled appointments cannot be edited');
        const business = await db.business.findUniqueOrThrow({ where: { id: businessId } });
        const serviceIds = input.serviceIds ?? existing.services.map((s) => s.serviceId);
        const totals = await this.availability.serviceTotals(db, businessId, serviceIds, false);
        const employee = await this.availability.resolveEmployee(db, businessId, input.employeeId ?? existing.employeeId);
        await lockEmployee(db, employee.id);
        const location = await this.resolveLocation(db, businessId, input.locationId ?? existing.locationId);
        if (input.clientId) {
          const c = await db.client.findFirst({ where: { id: input.clientId, businessId } });
          if (!c) throw new NotFoundException('Client not found');
        }
        const startsAt = input.startsAt ? new Date(input.startsAt) : existing.startsAt;
        const prevDuration = (+existing.endsAt - +existing.startsAt) / 60_000;
        const duration = input.durationMinutes ?? (input.serviceIds ? totals.duration : prevDuration);
        const endsAt = new Date(+startsAt + duration * 60_000);
        const moved = +startsAt !== +existing.startsAt || +endsAt !== +existing.endsAt || employee.id !== existing.employeeId;
        // Overlaps with other appointments are rejected by the DB exclusion constraint on update.
        if (moved && !input.allowOutsideHours) {
          const within = await this.withinWorkingHours(db, businessId, business.timezone, employee.id, startsAt, endsAt);
          if (!within) throw new BadRequestException({ code: 'OUTSIDE_WORKING_HOURS', message: 'Outside working hours' });
        }
        const priceChanged = !!input.serviceIds;
        const price = priceChanged ? totals.price : existing.priceMinor;
        const discount = input.discountPercent != null ? applyPercentDiscount(price, input.discountPercent).discount : priceChanged ? 0 : existing.discountMinor;
        if (input.serviceIds) {
          await db.appointmentService.deleteMany({ where: { appointmentId: id } });
          await db.appointmentService.createMany({ data: totals.services.map((s) => ({ appointmentId: id, serviceId: s.id, nameSnapshot: s.name, durationMinutes: s.durationMinutes, priceMinor: s.priceMinor })) });
        }
        const r = await db.appointment.updateMany({
          where: { id, version: input.version },
          data: {
            startsAt, endsAt, employeeId: employee.id, locationId: location.id,
            ...(input.clientId !== undefined ? { clientId: input.clientId } : {}),
            priceMinor: price, discountMinor: discount, notes: input.notes ?? existing.notes, version: { increment: 1 },
          },
        });
        if (r.count !== 1) throw new ConflictException({ code: 'VERSION_CONFLICT', message: 'Appointment was modified by someone else' });
        return { moved, previous: existing };
      });
      await this.audit.log(businessId, userId, 'update', 'appointment', id, input as unknown as Prisma.InputJsonValue);
      if (updated.moved) await this.waitlist.onSlotReleased(businessId, updated.previous.startsAt, updated.previous.endsAt);
      return this.get(businessId, id);
    } catch (e) {
      if (isOverlapViolation(e)) throw new SlotTakenException();
      throw e;
    }
  }

  async setStatus(businessId: string, userId: string | null, id: string, to: AppointmentStatus) {
    const existing = await this.prisma.appointment.findFirst({ where: { id, businessId } });
    if (!existing) throw new NotFoundException('Appointment not found');
    if (!TRANSITIONS[existing.status].includes(to)) {
      throw new BadRequestException({ code: 'INVALID_TRANSITION', message: `Cannot change ${existing.status} to ${to}` });
    }
    try {
      await this.prisma.$transaction(async (db) => {
        const r = await db.appointment.updateMany({ where: { id, status: existing.status }, data: { status: to, version: { increment: 1 } } });
        if (r.count !== 1) throw new ConflictException({ code: 'VERSION_CONFLICT', message: 'Status changed concurrently' });
        await db.appointmentStatusHistory.create({ data: { appointmentId: id, fromStatus: existing.status, toStatus: to, changedBy: userId } });
        if (to === 'CANCELLED') {
          await db.notificationJob.updateMany({ where: { dedupeKey: `reminder:${id}`, status: 'QUEUED' }, data: { status: 'FAILED', lastError: 'appointment cancelled' } });
        }
      });
    } catch (e) {
      if (isOverlapViolation(e)) throw new SlotTakenException(); // e.g. restoring a no-show into a slot that was re-booked
      throw e;
    }
    await this.audit.log(businessId, userId, 'status', 'appointment', id, { from: existing.status, to });
    if (to === 'CANCELLED' || to === 'NO_SHOW') await this.waitlist.onSlotReleased(businessId, existing.startsAt, existing.endsAt);
    return this.get(businessId, id);
  }

  private async withinWorkingHours(db: Prisma.TransactionClient, businessId: string, zone: string, employeeId: string, start: Date, end: Date) {
    const ctx = await this.availability.loadContext(db, businessId, employeeId, start, end);
    const date = DateTime.fromJSDate(start, { zone });
    for (const d of [date.minus({ days: 1 }), date]) {
      const working = workingIntervals(d.toISODate()!, { timezone: zone, rules: ctx.rules, overrides: ctx.overrides });
      if (working.some((w) => w.start <= start && w.end >= end)) return true;
    }
    return false;
  }

  private async resolveLocation(db: Prisma.TransactionClient, businessId: string, locationId?: string) {
    const loc = await db.workLocation.findFirst({ where: { businessId, isActive: true, ...(locationId ? { id: locationId } : {}) }, orderBy: { createdAt: 'asc' } });
    if (!loc) throw new NotFoundException('Location not found');
    return loc;
  }

  private async scheduleClientNotifications(db: Prisma.TransactionClient, businessId: string, appointmentId: string, client: { fullName: string; phone: string | null; email: string | null }, startsAt: Date, services: string) {
    const recipient = client.phone ?? client.email;
    if (!recipient) return;
    const channel = client.phone ? 'SMS' : 'EMAIL';
    const payload = { clientName: client.fullName, startsAt: startsAt.toISOString(), services };
    await this.notifications.enqueue(db, { businessId, channel, recipient, template: 'booking_confirmation', payload, dedupeKey: `confirm:${appointmentId}` });
    const reminderAt = new Date(+startsAt - 24 * 3_600_000);
    if (reminderAt > new Date()) {
      await this.notifications.enqueue(db, { businessId, channel, recipient, template: 'appointment_reminder', payload, dedupeKey: `reminder:${appointmentId}`, scheduledFor: reminderAt });
    }
  }
}
