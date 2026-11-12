/**
 * Availability engine — pure, deterministic, no I/O.
 *
 * All instants are UTC `Date`s. Local scheduling (working hours, dates) is evaluated
 * in the business IANA timezone with Luxon, so DST transitions and overnight shifts
 * are handled by wall-clock construction rather than by adding fixed offsets.
 *
 * This is the ONLY place slot availability is computed. The mobile app, the public
 * booking site and the free-slot sharing card all call API endpoints backed by it.
 */
import { DateTime } from 'luxon';

export interface Interval {
  start: Date;
  end: Date; // exclusive
}

export interface WeeklyRule {
  weekday: number; // ISO 1=Mon … 7=Sun
  startMinute: number; // minutes from local midnight
  endMinute: number; // may exceed 1440 => overnight shift ending next day
  breakStartMinute?: number | null;
  breakEndMinute?: number | null;
  locationId?: string;
}

export interface DayOverride {
  date: string; // local YYYY-MM-DD
  isClosed: boolean;
  startMinute?: number | null;
  endMinute?: number | null;
}

export interface AvailabilityInput {
  timezone: string;
  fromDate: string; // local YYYY-MM-DD inclusive
  toDate: string; // local YYYY-MM-DD inclusive
  rules: WeeklyRule[];
  overrides?: DayOverride[];
  busy: Interval[]; // existing active appointments, personal events …
  durationMinutes: number;
  bufferMinutes?: number;
  stepMinutes: number;
  now: Date;
  minNoticeMinutes?: number;
  maxHorizonDays?: number;
  locationId?: string;
  /** 'all' = every step-aligned slot; 'compact' = greedy non-overlapping slots (used for share cards). */
  mode?: 'all' | 'compact';
}

export interface Slot {
  start: Date;
  end: Date;
  localDate: string;
  localTime: string; // HH:mm in business timezone
}

export type UnavailableReason = 'DAY_OFF' | 'NOT_WORKING' | 'PAST_OR_NOTICE' | 'BEYOND_HORIZON' | 'FULLY_BOOKED';

export interface DayAvailability {
  date: string;
  slots: Slot[];
  reason?: UnavailableReason;
}

const MIN = 60_000;

/** Wall-clock local time → UTC instant. minute may be >= 1440 (next day). */
export function localMinuteToUtc(date: string, minute: number, zone: string): Date {
  const base = DateTime.fromISO(date, { zone });
  const day = base.plus({ days: Math.floor(minute / 1440) });
  const m = minute % 1440;
  return day.set({ hour: Math.floor(m / 60), minute: m % 60, second: 0, millisecond: 0 }).toUTC().toJSDate();
}

export function overlaps(a: Interval, b: Interval): boolean {
  return a.start < b.end && b.start < a.end;
}

/** Working intervals for one local date (after overrides and breaks). */
export function workingIntervals(date: string, input: Pick<AvailabilityInput, 'timezone' | 'rules' | 'overrides' | 'locationId'>): Interval[] {
  const zone = input.timezone;
  const override = input.overrides?.find((o) => o.date === date);
  if (override?.isClosed) return [];
  const weekday = DateTime.fromISO(date, { zone }).weekday;
  let rules: WeeklyRule[] = input.rules.filter((r) => r.weekday === weekday && (!input.locationId || !r.locationId || r.locationId === input.locationId));
  if (override && override.startMinute != null && override.endMinute != null) {
    rules = [{ weekday, startMinute: override.startMinute, endMinute: override.endMinute }];
  }
  const out: Interval[] = [];
  for (const r of rules) {
    const segments: [number, number][] =
      r.breakStartMinute != null && r.breakEndMinute != null && r.breakEndMinute > r.breakStartMinute
        ? [[r.startMinute, r.breakStartMinute], [r.breakEndMinute, r.endMinute]]
        : [[r.startMinute, r.endMinute]];
    for (const [s, e] of segments) {
      if (e <= s) continue;
      out.push({ start: localMinuteToUtc(date, s, zone), end: localMinuteToUtc(date, e, zone) });
    }
  }
  return out.sort((a, b) => +a.start - +b.start);
}

/** Free gaps inside working hours (used for "свободно: 45 мин" rows). */
export function freeGaps(working: Interval[], busy: Interval[]): Interval[] {
  const gaps: Interval[] = [];
  const sortedBusy = [...busy].sort((a, b) => +a.start - +b.start);
  for (const w of working) {
    let cursor = w.start;
    for (const b of sortedBusy) {
      if (b.end <= cursor || b.start >= w.end) continue;
      if (b.start > cursor) gaps.push({ start: cursor, end: new Date(Math.min(+b.start, +w.end)) });
      if (b.end > cursor) cursor = b.end;
      if (cursor >= w.end) break;
    }
    if (cursor < w.end) gaps.push({ start: cursor, end: w.end });
  }
  return gaps;
}

function eachDate(from: string, to: string, zone: string): string[] {
  const out: string[] = [];
  let d = DateTime.fromISO(from, { zone });
  const end = DateTime.fromISO(to, { zone });
  if (!d.isValid || !end.isValid) throw new Error('Invalid date range');
  let guard = 0;
  while (d <= end) {
    out.push(d.toISODate()!);
    d = d.plus({ days: 1 });
    if (++guard > 400) throw new Error('Date range too large');
  }
  return out;
}

export function computeAvailability(input: AvailabilityInput): DayAvailability[] {
  if (input.durationMinutes <= 0) throw new Error('durationMinutes must be positive');
  if (input.stepMinutes <= 0) throw new Error('stepMinutes must be positive');
  const zone = input.timezone;
  const buffer = input.bufferMinutes ?? 0;
  const earliest = new Date(+input.now + (input.minNoticeMinutes ?? 0) * MIN);
  const latest = input.maxHorizonDays != null ? new Date(+input.now + input.maxHorizonDays * 86_400_000) : null;
  const busy = [...input.busy].sort((a, b) => +a.start - +b.start);
  const result: DayAvailability[] = [];

  for (const date of eachDate(input.fromDate, input.toDate, zone)) {
    const override = input.overrides?.find((o) => o.date === date);
    const working = workingIntervals(date, input);
    if (override?.isClosed) { result.push({ date, slots: [], reason: 'DAY_OFF' }); continue; }
    if (working.length === 0) { result.push({ date, slots: [], reason: 'NOT_WORKING' }); continue; }

    const slots: Slot[] = [];
    let anyBeforeNotice = false;
    let anyBeyondHorizon = false;
    for (const w of working) {
      let t = +w.start;
      while (t + input.durationMinutes * MIN <= +w.end) {
        const candidate: Interval = { start: new Date(t), end: new Date(t + input.durationMinutes * MIN) };
        const blocked: Interval = { start: candidate.start, end: new Date(+candidate.end + buffer * MIN) };
        if (candidate.start < earliest) { anyBeforeNotice = true; t += input.stepMinutes * MIN; continue; }
        if (latest && candidate.start > latest) { anyBeyondHorizon = true; break; }
        const conflict = busy.find((b) => overlaps(b, blocked));
        if (conflict) {
          // jump past the conflicting interval, re-aligned to the step grid of this working window
          const stepsPast = Math.ceil((+conflict.end - +w.start) / (input.stepMinutes * MIN));
          t = Math.max(t + input.stepMinutes * MIN, +w.start + stepsPast * input.stepMinutes * MIN);
          continue;
        }
        const local = DateTime.fromJSDate(candidate.start, { zone });
        slots.push({ ...candidate, localDate: date, localTime: local.toFormat('HH:mm') });
        t += (input.mode === 'compact' ? input.durationMinutes + buffer : input.stepMinutes) * MIN;
      }
    }
    let reason: UnavailableReason | undefined;
    if (slots.length === 0) reason = anyBeyondHorizon ? 'BEYOND_HORIZON' : anyBeforeNotice ? 'PAST_OR_NOTICE' : 'FULLY_BOOKED';
    result.push({ date, slots, reason });
  }
  return result;
}

/** True if [start, start+duration) is a slot the engine would offer (used to validate public bookings). */
export function isSlotAvailable(input: Omit<AvailabilityInput, 'fromDate' | 'toDate' | 'mode'>, start: Date): boolean {
  const date = DateTime.fromJSDate(start, { zone: input.timezone }).toISODate()!;
  // also consider the previous local day for overnight shifts
  const prev = DateTime.fromISO(date, { zone: input.timezone }).minus({ days: 1 }).toISODate()!;
  const days = computeAvailability({ ...input, fromDate: prev, toDate: date, mode: 'all' });
  return days.some((d) => d.slots.some((s) => +s.start === +start));
}
