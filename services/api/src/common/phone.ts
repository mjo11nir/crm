/** Normalises a phone number to digits only (leading + dropped) for duplicate detection & lookup. */
export function normalizePhone(phone?: string | null): string | null {
  if (!phone) return null;
  const digits = phone.replace(/\D/g, '');
  return digits.length >= 6 ? digits : null;
}
