import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Tenant, TenantContext } from '../common/auth';
import { RequiresFeature } from '../subscriptions/entitlement.guard';
import { ClientDto, ImportClientsDto, MergeClientsDto, UpdateClientDto } from './clients.dto';
import { ClientsService } from './clients.service';

@ApiTags('clients')
@ApiBearerAuth()
@RequiresFeature('crm')
@Controller('businesses/:businessId/clients')
export class ClientsController {
  constructor(private readonly clients: ClientsService) {}

  @Get()
  list(@Tenant() t: TenantContext, @Query('q') q?: string, @Query('archived') archived?: string, @Query('tag') tag?: string, @Query('take') take?: string, @Query('skip') skip?: string) {
    return this.clients.list(t.businessId, { q, archived: archived === 'true', tag, take: take ? Number(take) : undefined, skip: skip ? Number(skip) : undefined });
  }

  @Get('duplicates')
  duplicates(@Tenant() t: TenantContext) {
    return this.clients.duplicates(t.businessId);
  }

  @Get('export.csv') @Header('Content-Type', 'text/csv; charset=utf-8') @Header('Content-Disposition', 'attachment; filename="clients.csv"')
  export(@Tenant() t: TenantContext) {
    return this.clients.exportCsv(t.businessId);
  }

  @Post('import')
  import(@Tenant() t: TenantContext, @Body() dto: ImportClientsDto) {
    return this.clients.importCsv(t.businessId, dto.csv);
  }

  @Post('merge')
  merge(@Tenant() t: TenantContext, @Body() dto: MergeClientsDto) {
    return this.clients.merge(t.businessId, dto.sourceId, dto.targetId);
  }

  @Post()
  create(@Tenant() t: TenantContext, @Body() dto: ClientDto) {
    return this.clients.create(t.businessId, dto);
  }

  @Get(':id')
  profile(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    return this.clients.profile(t.businessId, id);
  }

  @Patch(':id')
  update(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateClientDto) {
    return this.clients.update(t.businessId, id, dto);
  }

  @Post(':id/archive')
  archive(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    return this.clients.archive(t.businessId, id, true);
  }

  @Post(':id/unarchive')
  unarchive(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    return this.clients.archive(t.businessId, id, false);
  }
}
