import { BadRequestException, Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AvailabilityService } from '../availability/availability.service';
import { Tenant, TenantContext } from '../common/auth';
import { RequiresFeature } from '../subscriptions/entitlement.guard';
import { CreateAppointmentDto, StatusDto, UpdateAppointmentDto } from './appointments.dto';
import { AppointmentsService } from './appointments.service';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags('appointments')
@ApiBearerAuth()
@RequiresFeature('calendar')
@Controller('businesses/:businessId')
export class AppointmentsController {
  constructor(private readonly appointments: AppointmentsService, private readonly availability: AvailabilityService) {}

  @Get('appointments')
  list(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string, @Query('employeeId') employeeId?: string, @Query('q') q?: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    return this.appointments.range(t.businessId, from, to, { employeeId, q });
  }

  @Get('calendar/day')
  day(@Tenant() t: TenantContext, @Query('date') date: string, @Query('employeeId') employeeId?: string) {
    if (!DATE.test(date ?? '')) throw new BadRequestException('date must be YYYY-MM-DD');
    return this.appointments.day(t.businessId, date, employeeId);
  }

  @Get('calendar/dots')
  dots(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    return this.appointments.monthDots(t.businessId, from, to);
  }

  /** Staff availability query (no online notice/horizon restrictions). */
  @Get('availability')
  async slots(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string, @Query('serviceIds') serviceIds?: string, @Query('employeeId') employeeId?: string, @Query('mode') mode?: 'all' | 'compact', @Query('duration') duration?: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    return this.availability.query({
      businessId: t.businessId, fromDate: from, toDate: to, employeeId, online: false, mode: mode === 'compact' ? 'compact' : 'all',
      serviceIds: serviceIds ? serviceIds.split(',').filter(Boolean) : [], durationOverride: duration ? Number(duration) : undefined,
    });
  }

  @Get('appointments/:id')
  get(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    return this.appointments.get(t.businessId, id);
  }

  @Post('appointments')
  create(@Tenant() t: TenantContext, @Body() dto: CreateAppointmentDto) {
    return this.appointments.create(t.businessId, t.userId, dto);
  }

  @Patch('appointments/:id')
  update(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateAppointmentDto) {
    return this.appointments.update(t.businessId, t.userId, id, dto);
  }

  @Post('appointments/:id/status')
  status(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: StatusDto) {
    return this.appointments.setStatus(t.businessId, t.userId, id, dto.status);
  }
}
