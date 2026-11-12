import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Tenant, TenantContext } from '../common/auth';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('businesses/:businessId/notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}
  @Get()
  list(@Tenant() t: TenantContext) {
    return this.notifications.list(t.businessId);
  }
}
