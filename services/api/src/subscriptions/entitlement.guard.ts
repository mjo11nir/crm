import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../common/prisma.service';
import { Feature, hasFeature } from './entitlements';

export const FEATURE = 'feature';
/** Server-side entitlement enforcement: request fails with 402 if the business plan lacks the feature. */
export const RequiresFeature = (f: Feature) => SetMetadata(FEATURE, f);

@Injectable()
export class EntitlementGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly prisma: PrismaService) {}
  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const feature = this.reflector.getAllAndOverride<Feature | undefined>(FEATURE, [ctx.getHandler(), ctx.getClass()]);
    if (!feature) return true;
    const req = ctx.switchToHttp().getRequest();
    // Reads stay available after expiry so users can always access/export their data; writes require an entitlement.
    const isRead = req.method === 'GET' && feature !== 'excel_export';
    if (isRead) return true;
    const businessId: string | undefined = req.tenant?.businessId ?? req.params?.businessId;
    if (!businessId) return true;
    const sub = await this.prisma.subscription.findUnique({ where: { businessId } });
    if (!hasFeature(sub, feature)) {
      throw new HttpException({ code: 'SUBSCRIPTION_REQUIRED', feature, message: 'Your plan does not include this feature' }, HttpStatus.PAYMENT_REQUIRED);
    }
    return true;
  }
}
