import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppointmentsController } from './appointments/appointments.controller';
import { AppointmentsService } from './appointments/appointments.service';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { AvailabilityModule } from './availability/availability.module';
import { BusinessController } from './business/business.controller';
import { CatalogController } from './catalog/catalog.controller';
import { ChatsController } from './chats/chats.controller';
import { ClientsController } from './clients/clients.controller';
import { ClientsService } from './clients/clients.service';
import { AuthGuard } from './common/auth';
import { CommonModule } from './common/common.module';
import { config } from './common/config';
import { HealthController } from './health.controller';
import { DashboardController } from './dashboard/dashboard.controller';
import { FinanceController } from './finance/finance.controller';
import { FinanceService } from './finance/finance.service';
import { NotificationsModule } from './notifications/notifications.module';
import { PublicBookingController } from './public-booking/public-booking.controller';
import { EntitlementGuard } from './subscriptions/entitlement.guard';
import { SubscriptionsController } from './subscriptions/subscriptions.controller';
import { WaitlistController } from './waitlist/waitlist.controller';
import { WaitlistService } from './waitlist/waitlist.service';

@Module({
  imports: [
    CommonModule,
    NotificationsModule,
    AvailabilityModule,
    JwtModule.registerAsync({ global: true, useFactory: () => ({ secret: config.jwtSecret, signOptions: { algorithm: 'HS256' }, verifyOptions: { algorithms: ['HS256'] } }) }),
    ThrottlerModule.forRoot({ throttlers: [{ ttl: 60_000, limit: process.env.NODE_ENV === 'test' ? 100_000 : 300 }], skipIf: () => process.env.NODE_ENV === 'test' }),
  ],
  controllers: [
    HealthController, AuthController, BusinessController, CatalogController, ClientsController, AppointmentsController,
    PublicBookingController, DashboardController, FinanceController, ChatsController, WaitlistController, SubscriptionsController,
  ],
  providers: [
    AuthService, ClientsService, AppointmentsService, FinanceService, WaitlistService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: EntitlementGuard },
  ],
})
export class AppModule {}
