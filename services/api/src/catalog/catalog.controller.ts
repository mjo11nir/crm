import { BadRequestException, Body, Controller, Delete, Get, HttpCode, NotFoundException, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles, Tenant, TenantContext } from '../common/auth';
import { PrismaService } from '../common/prisma.service';
import { RequiresFeature } from '../subscriptions/entitlement.guard';
import { CategoryDto, ServiceDto, UpdateServiceDto } from './catalog.dto';

@ApiTags('services')
@ApiBearerAuth()
@RequiresFeature('catalog')
@Controller('businesses/:businessId')
export class CatalogController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('services')
  list(@Tenant() t: TenantContext, @Query('includeInactive') includeInactive?: string) {
    return this.prisma.service.findMany({
      where: { businessId: t.businessId, ...(includeInactive === 'true' ? {} : { isActive: true }) },
      include: { category: true },
      orderBy: [{ category: { sortOrder: 'asc' } }, { name: 'asc' }],
    });
  }

  @Post('services') @Roles('OWNER', 'ADMIN')
  async create(@Tenant() t: TenantContext, @Body() dto: ServiceDto) {
    await this.checkCategory(t.businessId, dto.categoryId);
    if ((dto.depositMinor ?? 0) > dto.priceMinor) throw new BadRequestException('Deposit cannot exceed price');
    return this.prisma.service.create({ data: { ...dto, businessId: t.businessId } });
  }

  @Patch('services/:id') @Roles('OWNER', 'ADMIN')
  async update(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateServiceDto) {
    const existing = await this.prisma.service.findFirst({ where: { id, businessId: t.businessId } });
    if (!existing) throw new NotFoundException('Service not found');
    await this.checkCategory(t.businessId, dto.categoryId);
    if ((dto.depositMinor ?? existing.depositMinor) > (dto.priceMinor ?? existing.priceMinor)) throw new BadRequestException('Deposit cannot exceed price');
    return this.prisma.service.update({ where: { id }, data: dto });
  }

  /** Soft-delete: services referenced by appointment history are deactivated, never hard-deleted. */
  @Delete('services/:id') @Roles('OWNER', 'ADMIN') @HttpCode(204)
  async remove(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    const r = await this.prisma.service.updateMany({ where: { id, businessId: t.businessId }, data: { isActive: false } });
    if (!r.count) throw new NotFoundException('Service not found');
  }

  @Get('service-categories')
  categories(@Tenant() t: TenantContext) {
    return this.prisma.serviceCategory.findMany({ where: { businessId: t.businessId }, orderBy: { sortOrder: 'asc' } });
  }

  @Post('service-categories') @Roles('OWNER', 'ADMIN')
  createCategory(@Tenant() t: TenantContext, @Body() dto: CategoryDto) {
    return this.prisma.serviceCategory.create({ data: { ...dto, businessId: t.businessId } });
  }

  private async checkCategory(businessId: string, categoryId?: string) {
    if (!categoryId) return;
    const c = await this.prisma.serviceCategory.findFirst({ where: { id: categoryId, businessId } });
    if (!c) throw new BadRequestException('Unknown category');
  }
}
