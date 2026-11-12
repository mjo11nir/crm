/** All money is integer minor units (cents). Never use floats for currency. */
export function applyPercentDiscount(amountMinor: number, percent: number): { net: number; discount: number } {
  if (!Number.isInteger(amountMinor) || amountMinor < 0) throw new Error('amount must be a non-negative integer');
  const p = Math.min(100, Math.max(0, Math.trunc(percent)));
  const discount = Math.round((amountMinor * p) / 100);
  return { net: amountMinor - discount, discount };
}

/** Remaining balance = net price − successful deposits/payments + refunds. Never negative. */
export function remainingBalance(
  netPriceMinor: number,
  payments: { kind: 'DEPOSIT' | 'PAYMENT' | 'REFUND'; amountMinor: number; status: string }[],
): number {
  let paid = 0;
  for (const p of payments) {
    if (p.status !== 'SUCCEEDED') continue;
    paid += p.kind === 'REFUND' ? -p.amountMinor : p.amountMinor;
  }
  return Math.max(0, netPriceMinor - paid);
}
