import { parseCsv, toCsv } from '../../src/common/csv';
import { applyPercentDiscount, remainingBalance } from '../../src/common/money';
import { normalizePhone } from '../../src/common/phone';
import { effectiveStatus, hasFeature, trialDaysLeft } from '../../src/subscriptions/entitlements';

describe('money', () => {
  it('applies percent discounts in integer minor units', () => {
    expect(applyPercentDiscount(4500, 10)).toEqual({ net: 4050, discount: 450 });
    expect(applyPercentDiscount(999, 33)).toEqual({ net: 669, discount: 330 });
    expect(applyPercentDiscount(1000, 150)).toEqual({ net: 0, discount: 1000 });
    expect(() => applyPercentDiscount(10.5, 10)).toThrow();
  });
  it('computes remaining balance with deposits, payments and refunds without double counting', () => {
    const p = (kind: 'DEPOSIT' | 'PAYMENT' | 'REFUND', amountMinor: number, status = 'SUCCEEDED') => ({ kind, amountMinor, status });
    expect(remainingBalance(4500, [])).toBe(4500);
    expect(remainingBalance(4500, [p('DEPOSIT', 1000), p('PAYMENT', 3500)])).toBe(0);
    expect(remainingBalance(4500, [p('DEPOSIT', 1000), p('PAYMENT', 3500, 'PENDING')])).toBe(3500);
    expect(remainingBalance(4500, [p('PAYMENT', 4500), p('REFUND', 500)])).toBe(500);
  });
});

describe('entitlements', () => {
  const now = new Date('2026-11-12T00:00:00Z');
  const future = new Date('2026-11-20T00:00:00Z');
  const past = new Date('2026-11-01T00:00:00Z');
  it('trial grants premium features, not VIP ones', () => {
    const s = { tier: 'TRIAL' as const, status: 'ACTIVE' as const, expiresAt: future };
    expect(hasFeature(s, 'calendar', now)).toBe(true);
    expect(hasFeature(s, 'excel_export', now)).toBe(false);
    expect(trialDaysLeft(s, now)).toBe(8);
  });
  it('expired subscription grants nothing', () => {
    const s = { tier: 'VIP' as const, status: 'ACTIVE' as const, expiresAt: past };
    expect(effectiveStatus(s, now)).toBe('EXPIRED');
    expect(hasFeature(s, 'calendar', now)).toBe(false);
    expect(hasFeature(null, 'calendar', now)).toBe(false);
  });
  it('grace period keeps access; cancelled keeps access until period end', () => {
    expect(hasFeature({ tier: 'PREMIUM', status: 'GRACE', expiresAt: past }, 'crm', now)).toBe(true);
    expect(hasFeature({ tier: 'VIP', status: 'CANCELLED', expiresAt: future }, 'excel_export', now)).toBe(true);
    expect(hasFeature({ tier: 'VIP', status: 'CANCELLED', expiresAt: past }, 'excel_export', now)).toBe(false);
  });
});

describe('csv & phone', () => {
  it('round-trips quoted CSV and neutralises formulas', () => {
    const csv = toCsv(['a', 'b'], [['x, "y"', '=SUM(A1)']]);
    const rows = parseCsv(csv);
    expect(rows).toEqual([['a', 'b'], ['x, "y"', "'=SUM(A1)"]]);
  });
  it('normalises phones', () => {
    expect(normalizePhone('+90 (533) 000-00-00')).toBe('905330000000');
    expect(normalizePhone('12')).toBeNull();
  });
});
