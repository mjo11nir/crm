import { SubscriptionStatus, SubscriptionTier } from '@prisma/client';

export type Feature =
  | 'calendar' | 'crm' | 'online_booking' | 'notifications' | 'waitlist'
  | 'finance' | 'web_page' | 'catalog' | 'excel_export' | 'extended_themes'
  | 'priority_support' | 'regular_clients_only';

const PREMIUM: Feature[] = ['calendar', 'crm', 'online_booking', 'notifications', 'waitlist', 'finance', 'web_page', 'catalog'];
const VIP: Feature[] = [...PREMIUM, 'excel_export', 'extended_themes', 'priority_support', 'regular_clients_only'];

export const TIER_FEATURES: Record<SubscriptionTier, Feature[]> = {
  TRIAL: PREMIUM,
  PREMIUM,
  VIP,
};

export interface SubscriptionLike {
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  expiresAt: Date;
}

/** Effective status: a subscription past its expiry is treated as EXPIRED regardless of the stored status. */
export function effectiveStatus(sub: SubscriptionLike | null, now = new Date()): SubscriptionStatus {
  if (!sub) return 'EXPIRED';
  if (sub.status === 'CANCELLED' && sub.expiresAt > now) return 'ACTIVE'; // paid period still runs
  if (sub.expiresAt <= now) return sub.status === 'GRACE' ? 'GRACE' : 'EXPIRED';
  return sub.status;
}

export function hasFeature(sub: SubscriptionLike | null, feature: Feature, now = new Date()): boolean {
  const status = effectiveStatus(sub, now);
  if (status === 'EXPIRED') return false;
  return TIER_FEATURES[sub!.tier].includes(feature);
}

export function trialDaysLeft(sub: SubscriptionLike | null, now = new Date()): number | null {
  if (!sub || sub.tier !== 'TRIAL') return null;
  return Math.max(0, Math.ceil((sub.expiresAt.getTime() - now.getTime()) / 86_400_000));
}
