import { BadRequestException, Body, Controller, Delete, Get, HttpCode, NotFoundException, Param, ParseUUIDPipe, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuditService } from '../common/audit.service';
import { Roles, Tenant, TenantContext } from '../common/auth';
import { isValidZone } from '../common/dates';
import { isUniqueViolation } from '../common/errors';
import { PrismaService } from '../common/prisma.service';
import { LocationDto, ReplaceScheduleDto, ScheduleExceptionDto, UpdateBusinessDto } from './business.dto';

@ApiTags('business')
@ApiBearerAuth()
@Controller('businesses/:businessId')
export class BusinessController {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  @Get()
  get(@Tenant() t: TenantContext) {
    return this.prisma.business.findUniqueOrThrow({ where: { id: t.businessId }, include: { locations: { where: { isActive: true } }, employees: { where: { isActive: true } } } });
  }

  @Patch() @Roles('OWNER', 'ADMIN')
  async update(@Tenant() t: TenantContext, @Body() dto: UpdateBusinessDto) {
    if (dto.timezone && !isValidZone(dto.timezone)) throw new BadRequestException('Invalid IANA timezone');
    try {
      const b = await this.prisma.business.update({ where: { id: t.businessId }, data: dto });
      await this.audit.log(t.businessId, t.userId, 'update', 'business', b.id, dto as object);
      return b;
    } catch (e) {
      if (isUniqueViolation(e)) throw new BadRequestException('Slug already taken');
      throw e;
    }
  }

  // ---- locations ----
  @Get('locations')
  locations(@Tenant() t: TenantContext) {
    return this.prisma.workLocation.findMany({ where: { businessId: t.businessId }, orderBy: { createdAt: 'asc' } });
  }

  @Post('locations') @Roles('OWNER', 'ADMIN')
  createLocation(@Tenant() t: TenantContext, @Body() dto: LocationDto) {
    return this.prisma.workLocation.create({ data: { ...dto, businessId: t.businessId } });
  }

  @Patch('locations/:id') @Roles('OWNER', 'ADMIN')
  async updateLocation(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: LocationDto) {
    const r = await this.prisma.workLocation.updateMany({ where: { id, businessId: t.businessId }, data: dto });
    if (!r.count) throw new NotFoundException();
    return this.prisma.workLocation.findUnique({ where: { id } });
  }

  // ---- employees & schedules ----
  @Get('employees')
  employees(@Tenant() t: TenantContext) {
    return this.prisma.employee.findMany({ where: { businessId: t.businessId }, include: { schedules: { orderBy: { weekday: 'asc' } } }, orderBy: { createdAt: 'asc' } });
  }

  @Put('employees/:employeeId/schedule') @Roles('OWNER', 'ADMIN')
  async replaceSchedule(@Tenant() t: TenantContext, @Param('employeeId', ParseUUIDPipe) employeeId: string, @Body() dto: ReplaceScheduleDto) {
    await this.ownEmployee(t.businessId, employeeId);
    const locIds = [...new Set(dto.days.map((d) => d.locationId))];
    const locs = await this.prisma.workLocation.count({ where: { businessId: t.businessId, id: { in: locIds } } });
    if (locs !== locIds.length) throw new BadRequestException('Unknown location');
    for (const d of dto.days) {
      if (d.endMinute <= d.startMinute) throw new BadRequestException('endMinute must be after startMinute');
      if ((d.breakStartMinute == null) !== (d.breakEndMinute == null)) throw new BadRequestException('Break needs start and end');
      if (d.breakStartMinute != null && !(d.breakStartMinute > d.startMinute && d.breakEndMinute! < d.endMinute && d.breakEndMinute! > d.breakStartMinute)) {
        throw new BadRequestException('Break must be inside working hours');
      }
    }
    await this.prisma.$transaction([
      this.prisma.workSchedule.deleteMany({ where: { businessId: t.businessId, employeeId } }),
      this.prisma.workSchedule.createMany({ data: dto.days.map((d) => ({ ...d, businessId: t.businessId, employeeId })) }),
    ]);
    await this.audit.log(t.businessId, t.userId, 'replace', 'work_schedule', employeeId);
    return this.prisma.workSchedule.findMany({ where: { employeeId }, orderBy: { weekday: 'asc' } });
  }

  @Get('employees/:employeeId/exceptions')
  async exceptions(@Tenant() t: TenantContext, @Param('employeeId', ParseUUIDPipe) employeeId: string) {
    await this.ownEmployee(t.businessId, employeeId);
    return this.prisma.scheduleException.findMany({ where: { employeeId }, orderBy: { date: 'asc' } });
  }

  @Put('employees/:employeeId/exceptions') @Roles('OWNER', 'ADMIN')
  async upsertException(@Tenant() t: TenantContext, @Param('employeeId', ParseUUIDPipe) employeeId: string, @Body() dto: ScheduleExceptionDto) {
    await this.ownEmployee(t.businessId, employeeId);
    if (!dto.isClosed && (dto.startMinute == null || dto.endMinute == null || dto.endMinute <= dto.startMinute)) throw new BadRequestException('Custom hours need valid start/end');
    const date = new Date(`${dto.date}T00:00:00Z`);
    const data = { isClosed: dto.isClosed, startMinute: dto.startMinute ?? null, endMinute: dto.endMinute ?? null, note: dto.note };
    return this.prisma.scheduleException.upsert({
      where: { employeeId_date: { employeeId, date } },
      create: { ...data, date, employeeId, businessId: t.businessId },
      update: data,
    });
  }

  @Delete('employees/:employeeId/exceptions/:date') @Roles('OWNER', 'ADMIN') @HttpCode(204)
  async deleteException(@Tenant() t: TenantContext, @Param('employeeId', ParseUUIDPipe) employeeId: string, @Param('date') date: string) {
    await this.ownEmployee(t.businessId, employeeId);
    await this.prisma.scheduleException.deleteMany({ where: { employeeId, businessId: t.businessId, date: new Date(`${date}T00:00:00Z`) } });
  }

  private async ownEmployee(businessId: string, employeeId: string) {
    const e = await this.prisma.employee.findFirst({ where: { id: employeeId, businessId } });
    if (!e) throw new NotFoundException('Employee not found');
    return e;
  }
}
