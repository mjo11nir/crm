import { BadRequestException } from '@nestjs/common';
import { DateTime } from 'luxon';

export function parseLocalDate(value: string, zone: string): DateTime {
  const d = DateTime.fromISO(value, { zone });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || !d.isValid) throw new BadRequestException(`Invalid date ${value}, expected YYYY-MM-DD`);
  return d.startOf('day');
}

export function isValidZone(zone: string): boolean {
  return DateTime.local().setZone(zone).isValid;
}
