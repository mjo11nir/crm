// Server-side validation for the public booking form (also used client-side for instant feedback).
export interface BookingInput {
  serviceIds: string[];
  startsAt: string;
  employeeId?: string;
  client: { fullName: string; phone: string; email?: string };
  comment?: string;
  acceptPolicy: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateBooking(raw: unknown): { ok: true; value: BookingInput } | { ok: false; errors: Record<string, string> } {
  const errors: Record<string, string> = {};
  const r = (raw ?? {}) as Record<string, any>;
  const serviceIds = Array.isArray(r.serviceIds) ? r.serviceIds.filter((x: unknown) => typeof x === 'string') : [];
  if (serviceIds.length < 1 || serviceIds.length > 5 || !serviceIds.every((s: string) => UUID.test(s))) errors.serviceIds = 'Choose a service';
  if (typeof r.startsAt !== 'string' || Number.isNaN(Date.parse(r.startsAt))) errors.startsAt = 'Choose a time';
  if (r.employeeId != null && (typeof r.employeeId !== 'string' || !UUID.test(r.employeeId))) errors.employeeId = 'Invalid specialist';
  const c = (r.client ?? {}) as Record<string, any>;
  const fullName = typeof c.fullName === 'string' ? c.fullName.trim() : '';
  if (fullName.length < 2 || fullName.length > 160) errors.fullName = 'Enter your name';
  const phone = typeof c.phone === 'string' ? c.phone.trim() : '';
  if (phone.replace(/\D/g, '').length < 6 || phone.length > 32 || !/^[+\d\s()-]+$/.test(phone)) errors.phone = 'Enter a valid phone number';
  const email = typeof c.email === 'string' && c.email.trim() ? c.email.trim() : undefined;
  if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) errors.email = 'Enter a valid email';
  const comment = typeof r.comment === 'string' && r.comment.trim() ? r.comment.trim().slice(0, 500) : undefined;
  if (r.acceptPolicy !== true) errors.acceptPolicy = 'Please accept the booking policy';
  if (Object.keys(errors).length) return { ok: false, errors };
  return { ok: true, value: { serviceIds, startsAt: new Date(r.startsAt).toISOString(), employeeId: r.employeeId ?? undefined, client: { fullName, phone, email }, comment, acceptPolicy: true } };
}

export function isValidSlug(slug: string): boolean {
  return /^[a-z0-9][a-z0-9-]{0,62}$/.test(slug);
}

export function formatMoney(minor: number, currency: string, locale = 'ru-RU'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency, minimumFractionDigits: minor % 100 === 0 ? 0 : 2 }).format(minor / 100);
}
