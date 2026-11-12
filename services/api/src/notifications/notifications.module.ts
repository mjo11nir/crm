import { Global, Module } from '@nestjs/common';
import { DELIVERY_ADAPTER, SandboxAdapter } from './adapters';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Global()
@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, { provide: DELIVERY_ADAPTER, useValue: new SandboxAdapter() }],
  exports: [NotificationsService, DELIVERY_ADAPTER],
})
export class NotificationsModule {}
