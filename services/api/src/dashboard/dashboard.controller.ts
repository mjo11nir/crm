import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { DateTime } from 'luxon';
import { AppointmentsService } from '../appointments/appointments.service';
import { AvailabilityService } from '../availability/availability.service';
import { Tenant, TenantContext } from '../common/auth';
import { config } from '../common/config';
import { PrismaService } from '../common/prisma.service';
import { effectiveStatus, trialDaysLeft } from '../subscriptions/entitlements';
import { monthRevenue } from '../finance/finance.service';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('businesses/:businessId')
export class DashboardController {
  constructor(private readonly prisma: PrismaService, private readonly appointments: AppointmentsService, private readonly availability: AvailabilityService) {}

  /** Everything the Home screen shows, computed from live data. */
  @Get('dashboard')
  async dashboard(@Tenant() t: TenantContext, @Query('date') date?: string) {
    const b = await this.prisma.business.findUniqueOrThrow({ where: { id: t.businessId }, include: { subscription: true } });
    const today = DateTime.now().setZone(b.timezone);
    const selected = date && DATE.test(date) ? DateTime.fromISO(date, { zone: b.timezone }) : today;
    if (!selected.isValid) throw new BadRequestException('Invalid date');
    const weekStart = selected.startOf('week');
    const weekEnd = weekStart.plus({ days: 6 });
    const monthStart = selected.startOf('month');
    const [user, dayAppts, dots, totalClients, newClients, month] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: t.userId }, select: { fullName: true, avatarUrl: true } }),
      this.appointments.range(t.businessId, selected.toISODate()!, selected.toISODate()!),
      this.appointments.monthDots(t.businessId, weekStart.toISODate()!, weekEnd.toISODate()!),
      this.prisma.client.count({ where: { businessId: t.businessId, archivedAt: null } }),
      this.prisma.client.count({ where: { businessId: t.businessId, createdAt: { gte: monthStart.toJSDate(), lt: monthStart.plus({ months: 1 }).toJSDate() } } }),
      monthRevenue(this.prisma, t.businessId, monthStart.toJSDate(), monthStart.plus({ months: 1 }).toJSDate()),
    ]);
    const active = dayAppts.filter((a) => a.status !== 'CANCELLED' && a.status !== 'NO_SHOW');
    return {
      profile: { fullName: user.fullName, avatarUrl: user.avatarUrl ?? b.avatarUrl, businessName: b.name },
      subscription: b.subscription ? { tier: b.subscription.tier, status: effectiveStatus(b.subscription), trialDaysLeft: trialDaysLeft(b.subscription) } : null,
      today: today.toISODate(),
      selectedDate: selected.toISODate(),
      currency: b.currency,
      week: Array.from({ length: 7 }, (_, i) => {
        const d = weekStart.plus({ days: i }).toISODate()!;
        return { date: d, count: dots[d]?.total ?? 0 };
      }),
      appointments: active.map((a) => ({
        id: a.id, startsAt: a.startsAt, endsAt: a.endsAt, status: a.status,
        clientName: a.client?.fullName ?? null, services: a.services.map((s) => s.nameSnapshot).join(', '), netPriceMinor: a.netPriceMinor,
      })),
      dayRevenueMinor: active.reduce((s, a) => s + a.netPriceMinor, 0),
      clients: { total: totalClients, newThisMonth: newClients },
      finance: { month: monthStart.toFormat('yyyy-MM'), ...month },
    };
  }

  /** Free-slot sharing card data (Свободные окна). Uses the central availability engine in compact mode. */
  @Get('free-slots')
  async freeSlots(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string, @Query('serviceId') serviceId?: string, @Query('duration') duration?: string, @Query('locationId') locationId?: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    const b = await this.prisma.business.findUniqueOrThrow({ where: { id: t.businessId } });
    const location = locationId
      ? await this.prisma.workLocation.findFirst({ where: { id: locationId, businessId: t.businessId } })
      : await this.prisma.workLocation.findFirst({ where: { businessId: t.businessId, isActive: true }, orderBy: { createdAt: 'asc' } });
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: t.userId }, select: { fullName: true, phone: true, avatarUrl: true } });
    const durationMinutes = duration ? Math.max(15, Math.min(480, Number(duration) || 60)) : undefined;
    const result = await this.availability.query({
      businessId: t.businessId, fromDate: from, toDate: to, serviceIds: serviceId ? [serviceId] : [], locationId: location?.id,
      online: true, mode: 'compact', durationOverride: serviceId ? undefined : durationMinutes ?? 120,
    });
    return {
      card: { name: user.fullName, phone: b.phone ?? user.phone, avatarUrl: user.avatarUrl ?? b.avatarUrl, locationName: location?.name ?? null, address: location?.address ?? null, themeColor: b.themeColor },
      bookingUrl: `${config.publicBookingBaseUrl}/${b.slug}`,
      durationMinutes: result.durationMinutes,
      days: result.days.filter((d) => d.slots.length > 0).map((d) => ({ date: d.date, times: d.slots.map((s) => s.localTime) })),
    };
  }
}
