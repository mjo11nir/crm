import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

/** Postgres exclusion_violation raised by appointments_no_overlap. */
export function isOverlapViolation(e: unknown): boolean {
  const msg = e instanceof Error ? e.message : String(e);
  if (msg.includes('appointments_no_overlap') || msg.includes('23P01')) return true;
  if (msg.includes('40P01')) return true; // deadlock between competing bookings: one of them lost the slot
  if (e instanceof Prisma.PrismaClientUnknownRequestError || e instanceof Prisma.PrismaClientKnownRequestError) {
    return /exclusion|overlap/i.test(e.message);
  }
  return false;
}

export function isUniqueViolation(e: unknown): boolean {
  return e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';
}

export class SlotTakenException extends ConflictException {
  constructor() {
    super({ code: 'SLOT_TAKEN', message: 'This time is no longer available' });
  }
}
