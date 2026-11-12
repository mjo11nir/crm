import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsInt, IsOptional, IsUUID, Matches, Max, Min } from 'class-validator';
import { Tenant, TenantContext } from '../common/auth';
import { RequiresFeature } from '../subscriptions/entitlement.guard';
import { WaitlistService } from './waitlist.service';

class WaitlistDto {
  @ApiProperty() @IsUUID() clientId: string;
  @ApiProperty() @IsUUID() serviceId: string;
  @ApiProperty() @Matches(/^\d{4}-\d{2}-\d{2}$/) preferredFrom: string;
  @ApiProperty() @Matches(/^\d{4}-\d{2}-\d{2}$/) preferredTo: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(1440) fromMinute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(1440) toMinute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(10) priority?: number;
}

@ApiTags('waitlist')
@ApiBearerAuth()
@RequiresFeature('waitlist')
@Controller('businesses/:businessId/waitlist')
export class WaitlistController {
  constructor(private readonly waitlist: WaitlistService) {}
  @Get() list(@Tenant() t: TenantContext) { return this.waitlist.list(t.businessId); }
  @Post() add(@Tenant() t: TenantContext, @Body() dto: WaitlistDto) { return this.waitlist.add(t.businessId, dto); }
  @Delete(':id') @HttpCode(204)
  async remove(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) { await this.waitlist.remove(t.businessId, id); }
}
