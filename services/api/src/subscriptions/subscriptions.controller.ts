import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Tenant, TenantContext } from '../common/auth';
import { PrismaService } from '../common/prisma.service';
import { effectiveStatus, TIER_FEATURES, trialDaysLeft } from './entitlements';

@ApiTags('subscription')
@ApiBearerAuth()
@Controller('businesses/:businessId/subscription')
export class SubscriptionsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async get(@Tenant() t: TenantContext) {
    const sub = await this.prisma.subscription.findUnique({ where: { businessId: t.businessId } });
    return {
      tier: sub?.tier ?? null,
      status: effectiveStatus(sub),
      expiresAt: sub?.expiresAt ?? null,
      trialDaysLeft: trialDaysLeft(sub),
      features: sub && effectiveStatus(sub) !== 'EXPIRED' ? TIER_FEATURES[sub.tier] : [],
      // Store purchases (StoreKit / Google Play Billing) need store credentials — see docs/known-limitations.md
      storeBilling: 'BLOCKED_PENDING_STORE_CREDENTIALS',
    };
  }
}
