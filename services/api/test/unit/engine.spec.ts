import { computeAvailability, freeGaps, isSlotAvailable, localMinuteToUtc, workingIntervals } from '../../src/availability/engine';

const TZ = 'Europe/Istanbul'; // UTC+3, no DST
const base = {
  timezone: TZ,
  rules: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, startMinute: 540, endMinute: 1140 })), // 09–19
  busy: [],
  stepMinutes: 30,
  now: new Date('2026-01-01T00:00:00Z'),
};

describe('availability engine', () => {
  it('converts local wall-clock minutes to UTC', () => {
    expect(localMinuteToUtc('2026-11-16', 540, TZ).toISOString()).toBe('2026-11-16T06:00:00.000Z');
  });

  it('produces step-aligned slots inside working hours', () => {
    const [day] = computeAvailability({ ...base, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 120 });
    expect(day.slots[0].localTime).toBe('09:00');
    expect(day.slots.at(-1)!.localTime).toBe('17:00'); // 17:00 + 2h = 19:00 fits exactly
    expect(day.slots).toHaveLength(17);
  });

  it('marks weekends as NOT_WORKING', () => {
    const days = computeAvailability({ ...base, fromDate: '2026-11-21', toDate: '2026-11-22', durationMinutes: 60 });
    expect(days.map((d) => d.reason)).toEqual(['NOT_WORKING', 'NOT_WORKING']);
  });

  it('excludes busy intervals and respects buffer', () => {
    const busy = [{ start: localMinuteToUtc('2026-11-16', 660, TZ), end: localMinuteToUtc('2026-11-16', 780, TZ) }]; // 11–13
    const [day] = computeAvailability({ ...base, busy, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 60, bufferMinutes: 15 });
    const times = day.slots.map((s) => s.localTime);
    expect(times).toContain('09:30'); // 09:30–10:30 + 15 buffer = 10:45 < 11:00
    expect(times).not.toContain('10:00'); // 10:00–11:00 + 15 overlaps
    expect(times).not.toContain('12:00');
    expect(times).toContain('13:00');
  });

  it('compact mode yields non-overlapping slots like the share card (9, 11, 13, 15, 17)', () => {
    const [day] = computeAvailability({ ...base, fromDate: '2026-11-17', toDate: '2026-11-17', durationMinutes: 120, mode: 'compact' });
    expect(day.slots.map((s) => s.localTime)).toEqual(['09:00', '11:00', '13:00', '15:00', '17:00']);
  });

  it('compact mode shifts around existing bookings', () => {
    const busy = [{ start: localMinuteToUtc('2026-11-17', 540, TZ), end: localMinuteToUtc('2026-11-17', 660, TZ) }];
    const [day] = computeAvailability({ ...base, busy, fromDate: '2026-11-17', toDate: '2026-11-17', durationMinutes: 120, mode: 'compact' });
    expect(day.slots.map((s) => s.localTime)).toEqual(['11:00', '13:00', '15:00', '17:00']);
  });

  it('applies min notice and horizon', () => {
    const now = localMinuteToUtc('2026-11-16', 600, TZ); // 10:00 local
    const days = computeAvailability({ ...base, now, minNoticeMinutes: 120, maxHorizonDays: 1, fromDate: '2026-11-16', toDate: '2026-11-18', durationMinutes: 60 });
    expect(days[0].slots[0].localTime).toBe('12:00');
    expect(days[2].slots).toHaveLength(0);
    expect(days[2].reason).toBe('BEYOND_HORIZON');
  });

  it('reports FULLY_BOOKED and PAST_OR_NOTICE reasons', () => {
    const busy = [{ start: localMinuteToUtc('2026-11-16', 540, TZ), end: localMinuteToUtc('2026-11-16', 1140, TZ) }];
    expect(computeAvailability({ ...base, busy, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 60 })[0].reason).toBe('FULLY_BOOKED');
    const now = new Date('2026-12-01T00:00:00Z');
    expect(computeAvailability({ ...base, now, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 60 })[0].reason).toBe('PAST_OR_NOTICE');
  });

  it('honours breaks and day overrides', () => {
    const rules = [{ weekday: 1, startMinute: 540, endMinute: 1140, breakStartMinute: 780, breakEndMinute: 840 }];
    const [day] = computeAvailability({ ...base, rules, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 60, stepMinutes: 60 });
    expect(day.slots.map((s) => s.localTime)).not.toContain('13:00');
    expect(day.slots.map((s) => s.localTime)).toContain('14:00');
    const closed = computeAvailability({ ...base, overrides: [{ date: '2026-11-16', isClosed: true }], fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 60 });
    expect(closed[0].reason).toBe('DAY_OFF');
    const custom = computeAvailability({ ...base, overrides: [{ date: '2026-11-21', isClosed: false, startMinute: 600, endMinute: 720 }], fromDate: '2026-11-21', toDate: '2026-11-21', durationMinutes: 60, stepMinutes: 60 });
    expect(custom[0].slots.map((s) => s.localTime)).toEqual(['10:00', '11:00']);
  });

  it('handles DST spring-forward in Europe/Berlin (wall-clock hours stay correct)', () => {
    const rules = [{ weekday: 7, startMinute: 540, endMinute: 720 }];
    const [day] = computeAvailability({ ...base, timezone: 'Europe/Berlin', rules, fromDate: '2026-03-29', toDate: '2026-03-29', durationMinutes: 60, stepMinutes: 60 });
    expect(day.slots.map((s) => s.localTime)).toEqual(['09:00', '10:00', '11:00']);
    expect(day.slots[0].start.toISOString()).toBe('2026-03-29T07:00:00.000Z'); // CEST = UTC+2
    const [before] = computeAvailability({ ...base, timezone: 'Europe/Berlin', rules: [{ weekday: 7, startMinute: 540, endMinute: 600 }], fromDate: '2026-03-22', toDate: '2026-03-22', durationMinutes: 60, stepMinutes: 60 });
    expect(before.slots[0].start.toISOString()).toBe('2026-03-22T08:00:00.000Z'); // CET = UTC+1
  });

  it('handles DST fall-back day (25h day) in America/New_York', () => {
    const rules = [{ weekday: 7, startMinute: 0, endMinute: 240 }]; // 00:00–04:00 wall clock spans the repeated hour
    const [day] = computeAvailability({ ...base, timezone: 'America/New_York', rules, fromDate: '2026-11-01', toDate: '2026-11-01', durationMinutes: 60, stepMinutes: 60 });
    const w = workingIntervals('2026-11-01', { timezone: 'America/New_York', rules });
    expect((+w[0].end - +w[0].start) / 3_600_000).toBe(5); // 4 wall-clock hours = 5 real hours
    expect(day.slots.length).toBe(5);
  });

  it('supports overnight shifts crossing midnight', () => {
    const rules = [{ weekday: 5, startMinute: 1320, endMinute: 1560 }]; // Fri 22:00 – Sat 02:00
    const [fri] = computeAvailability({ ...base, rules, fromDate: '2026-11-20', toDate: '2026-11-20', durationMinutes: 60, stepMinutes: 60 });
    expect(fri.slots.map((s) => s.localTime)).toEqual(['22:00', '23:00', '00:00', '01:00']);
    expect(isSlotAvailable({ ...base, rules, durationMinutes: 60, stepMinutes: 60 }, localMinuteToUtc('2026-11-21', 60, TZ))).toBe(true);
  });

  it('freeGaps returns gaps between bookings', () => {
    const working = workingIntervals('2026-11-16', base);
    const busy = [{ start: localMinuteToUtc('2026-11-16', 540, TZ), end: localMinuteToUtc('2026-11-16', 660, TZ) }];
    const gaps = freeGaps(working, busy);
    expect(gaps).toHaveLength(1);
    expect((+gaps[0].end - +gaps[0].start) / 60_000).toBe(480);
  });

  it('isSlotAvailable rejects unaligned or busy starts', () => {
    const busy = [{ start: localMinuteToUtc('2026-11-16', 600, TZ), end: localMinuteToUtc('2026-11-16', 660, TZ) }];
    const input = { ...base, busy, durationMinutes: 60 };
    expect(isSlotAvailable(input, localMinuteToUtc('2026-11-16', 540, TZ))).toBe(true);
    expect(isSlotAvailable(input, localMinuteToUtc('2026-11-16', 545, TZ))).toBe(false);
    expect(isSlotAvailable(input, localMinuteToUtc('2026-11-16', 600, TZ))).toBe(false);
  });

  it('rejects invalid input', () => {
    expect(() => computeAvailability({ ...base, fromDate: '2026-11-16', toDate: '2026-11-16', durationMinutes: 0 })).toThrow();
    expect(() => computeAvailability({ ...base, fromDate: '2020-01-01', toDate: '2026-01-01', durationMinutes: 30 })).toThrow('too large');
  });
});
