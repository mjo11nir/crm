import { BadRequestException, Body, ConflictException, Controller, Get, Headers, NotFoundException, Param, Post, Query } from '@nestjs/common';
import { ApiHeader, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, Equals, IsArray, IsEmail, IsISO8601, IsOptional, IsString, IsUUID, MaxLength, MinLength, ValidateNested } from 'class-validator';
import { Prisma } from '@prisma/client';
import { createHash } from 'crypto';
import { AppointmentsService } from '../appointments/appointments.service';
import { AvailabilityService } from '../availability/availability.service';
import { Public } from '../common/auth';
import { isUniqueViolation } from '../common/errors';
import { normalizePhone } from '../common/phone';
import { PrismaService } from '../common/prisma.service';
import { hasFeature } from '../subscriptions/entitlements';

class BookingClientDto {
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(160) fullName: string;
  @ApiProperty() @IsString() @MinLength(6) @MaxLength(32) phone: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
}

export class PublicBookingDto {
  @ApiProperty({ type: [String] }) @IsArray() @ArrayMinSize(1) @ArrayMaxSize(5) @IsUUID('all', { each: true }) serviceIds: string[];
  @ApiPropertyOptional() @IsOptional() @IsUUID() employeeId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() locationId?: string;
  @ApiProperty() @IsISO8601({ strict: true }) startsAt: string;
  @ApiProperty() @ValidateNested() @Type(() => BookingClientDto) client: BookingClientDto;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) comment?: string;
  @ApiProperty() @Equals(true, { message: 'You must accept the booking policy' }) acceptPolicy: boolean;
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags('public booking')
@Public()
@Controller('public/:slug')
export class PublicBookingController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: AvailabilityService,
    private readonly appointments: AppointmentsService,
  ) {}

  private async business(slug: string) {
    const b = await this.prisma.business.findUnique({ where: { slug }, include: { subscription: true } });
    if (!b || !b.onlineBookingEnabled || !hasFeature(b.subscription, 'online_booking')) throw new NotFoundException('Booking page not found');
    return b;
  }

  @Get()
  async info(@Param('slug') slug: string) {
    const b = await this.business(slug);
    const [services, locations, employees, schedules] = await Promise.all([
      this.prisma.service.findMany({ where: { businessId: b.id, isActive: true, onlineBookable: true }, include: { category: true }, orderBy: { name: 'asc' } }),
      this.prisma.workLocation.findMany({ where: { businessId: b.id, isActive: true }, select: { id: true, name: true, address: true } }),
      this.prisma.employee.findMany({ where: { businessId: b.id, isActive: true }, select: { id: true, displayName: true } }),
      this.prisma.workSchedule.findMany({ where: { businessId: b.id }, select: { weekday: true, startMinute: true, endMinute: true }, orderBy: { weekday: 'asc' } }),
    ]);
    return {
      business: { name: b.name, slug: b.slug, phone: b.phone, description: b.description, avatarUrl: b.avatarUrl, themeColor: b.themeColor, timezone: b.timezone, currency: b.currency, maxHorizonDays: b.maxHorizonDays, cancellationDeadlineMin: b.cancellationDeadlineMin, requireApproval: b.requireApproval },
      services: services.map((s) => ({ id: s.id, name: s.name, description: s.description, category: s.category?.name ?? null, durationMinutes: s.durationMinutes, priceMinor: s.priceMinor, depositMinor: s.depositMinor })),
      locations, employees, workingHours: schedules,
    };
  }

  @Get('availability') @Throttle({ default: { limit: 60, ttl: 60_000 } })
  async slots(@Param('slug') slug: string, @Query('from') from: string, @Query('to') to: string, @Query('serviceIds') serviceIds: string, @Query('employeeId') employeeId?: string, @Query('locationId') locationId?: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    if (!serviceIds) throw new BadRequestException('serviceIds required');
    const b = await this.business(slug);
    return this.availability.query({ businessId: b.id, fromDate: from, toDate: to, serviceIds: serviceIds.split(',').filter(Boolean), employeeId, locationId, online: true });
  }

  /**
   * Atomic + idempotent booking. The client sends an `Idempotency-Key` header (UUID);
   * replays return the original response, a different payload under the same key is rejected.
   * Double booking is impossible: the insert is protected by the DB exclusion constraint.
   */
  @Post('bookings') @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  async book(@Param('slug') slug: string, @Body() dto: PublicBookingDto, @Headers('idempotency-key') key?: string) {
    if (!key || !/^[A-Za-z0-9-]{16,64}$/.test(key)) throw new BadRequestException('Idempotency-Key header (16-64 chars) is required');
    const b = await this.business(slug);
    const requestHash = createHash('sha256').update(JSON.stringify(dto)).digest('hex');
    try {
      await this.prisma.idempotencyKey.create({ data: { businessId: b.id, key, scope: 'public_booking', requestHash } });
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      const existing = await this.prisma.idempotencyKey.findUniqueOrThrow({ where: { businessId_scope_key: { businessId: b.id, scope: 'public_booking', key } } });
      if (existing.requestHash !== requestHash) throw new ConflictException({ code: 'IDEMPOTENCY_MISMATCH', message: 'Key reused with a different request' });
      if (existing.responseBody == null) throw new ConflictException({ code: 'IN_PROGRESS', message: 'Request is being processed' });
      return existing.responseBody;
    }
    try {
      const totals = await this.availability.serviceTotals(this.prisma, b.id, dto.serviceIds, true);
      if (totals.deposit > 0) {
        // Deposits require a verified payment-provider payment; no provider is configured yet.
        throw new ConflictException({ code: 'DEPOSIT_PROVIDER_UNAVAILABLE', message: 'Online deposit payment is not available yet. Please contact the business.' });
      }
      const response = await this.prisma.$transaction(async (tx) => {
        const phoneNormalized = normalizePhone(dto.client.phone);
        let client = phoneNormalized ? await tx.client.findFirst({ where: { businessId: b.id, phoneNormalized, archivedAt: null } }) : null;
        client ??= await tx.client.create({ data: { businessId: b.id, fullName: dto.client.fullName.trim(), phone: dto.client.phone, phoneNormalized, email: dto.client.email } });
        const appt = await this.appointments.createOne(b.id, null, {
          clientId: client.id, serviceIds: dto.serviceIds, employeeId: dto.employeeId, locationId: dto.locationId, startsAt: dto.startsAt, notes: dto.comment,
        }, 'ONLINE', tx);
        if (!b.requireApproval) {
          await tx.appointment.update({ where: { id: appt.id }, data: { status: 'CONFIRMED' } });
          await tx.appointmentStatusHistory.create({ data: { appointmentId: appt.id, fromStatus: 'BOOKED', toStatus: 'CONFIRMED' } });
        }
        const body = {
          bookingId: appt.id, status: b.requireApproval ? 'PENDING_APPROVAL' : 'CONFIRMED',
          startsAt: appt.startsAt, endsAt: appt.endsAt, services: appt.services.map((s) => s.nameSnapshot),
          priceMinor: appt.netPriceMinor, currency: b.currency, business: { name: b.name, phone: b.phone },
        };
        await tx.idempotencyKey.update({ where: { businessId_scope_key: { businessId: b.id, scope: 'public_booking', key } }, data: { responseBody: body, statusCode: 201 } });
        return body;
      });
      return response;
    } catch (e) {
      await this.prisma.idempotencyKey.deleteMany({ where: { businessId: b.id, scope: 'public_booking', key, responseBody: { equals: Prisma.AnyNull } } }).catch(() => undefined);
      throw e;
    }
  }
}
