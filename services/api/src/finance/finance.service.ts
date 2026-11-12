import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DateTime } from 'luxon';
import { parseLocalDate } from '../common/dates';
import { remainingBalance } from '../common/money';
import { PrismaService } from '../common/prisma.service';

type Db = PrismaService | Prisma.TransactionClient;

/**
 * Revenue definitions (documented in docs/finance.md):
 *  - earned revenue  = Σ net price (price − discount) of COMPLETED appointments, by appointment date
 *  - planned revenue = Σ net price of BOOKED/CONFIRMED appointments in the period
 *  - cash in         = Σ SUCCEEDED deposits + payments − refunds, by payment date (cash-flow view)
 * Deposits and final payments are both cash-in for the same appointment; earned revenue never
 * double-counts because it is derived from the appointment, not from payments.
 */
export async function monthRevenue(db: Db, businessId: string, from: Date, to: Date) {
  const rows = await db.appointment.groupBy({
    by: ['status'],
    where: { businessId, startsAt: { gte: from, lt: to }, status: { in: ['BOOKED', 'CONFIRMED', 'COMPLETED'] } },
    _sum: { priceMinor: true, discountMinor: true },
  });
  const net = (s: string[]) => rows.filter((r) => s.includes(r.status)).reduce((a, r) => a + (r._sum.priceMinor ?? 0) - (r._sum.discountMinor ?? 0), 0);
  const completedMinor = net(['COMPLETED']);
  const plannedMinor = net(['BOOKED', 'CONFIRMED']);
  return { totalMinor: completedMinor + plannedMinor, completedMinor, plannedMinor };
}

export interface PaymentInput {
  kind: 'DEPOSIT' | 'PAYMENT' | 'REFUND';
  method: 'CASH' | 'CARD' | 'TRANSFER';
  amountMinor: number;
}

@Injectable()
export class FinanceService {
  constructor(private readonly prisma: PrismaService) {}

  async recordPayment(businessId: string, appointmentId: string, input: PaymentInput) {
    return this.prisma.$transaction(async (tx) => {
      // lock the appointment row so concurrent payments cannot overpay
      await tx.$queryRaw`SELECT id FROM appointments WHERE id = ${appointmentId}::uuid AND "businessId" = ${businessId}::uuid FOR UPDATE`;
      const appt = await tx.appointment.findFirst({ where: { id: appointmentId, businessId }, include: { payments: true } });
      if (!appt) throw new NotFoundException('Appointment not found');
      const business = await tx.business.findUniqueOrThrow({ where: { id: businessId } });
      const net = appt.priceMinor - appt.discountMinor;
      const balance = remainingBalance(net, appt.payments);
      const paid = net - balance;
      if (input.kind === 'REFUND') {
        if (input.amountMinor > paid) throw new BadRequestException('Refund exceeds amount paid');
      } else {
        if (appt.status === 'CANCELLED') throw new BadRequestException('Appointment is cancelled');
        if (input.amountMinor > balance) throw new BadRequestException(`Amount exceeds remaining balance (${balance})`);
      }
      await tx.payment.create({
        data: { businessId, appointmentId, clientId: appt.clientId, kind: input.kind, method: input.method, amountMinor: input.amountMinor, currency: business.currency, status: 'SUCCEEDED' },
      });
      const payments = await tx.payment.findMany({ where: { appointmentId }, orderBy: { paidAt: 'asc' } });
      return { netPriceMinor: net, balanceMinor: remainingBalance(net, payments), payments };
    });
  }

  async report(businessId: string, fromDate: string, toDate: string) {
    const b = await this.prisma.business.findUniqueOrThrow({ where: { id: businessId } });
    const from = parseLocalDate(fromDate, b.timezone).toJSDate();
    const to = parseLocalDate(toDate, b.timezone).plus({ days: 1 }).toJSDate();
    const [appts, payments, expenses, newClients] = await Promise.all([
      this.prisma.appointment.findMany({ where: { businessId, startsAt: { gte: from, lt: to } }, include: { services: true, employee: true, location: true } }),
      this.prisma.payment.findMany({ where: { businessId, paidAt: { gte: from, lt: to }, status: 'SUCCEEDED' } }),
      this.prisma.expense.findMany({ where: { businessId, spentAt: { gte: from, lt: to } } }),
      this.prisma.client.count({ where: { businessId, createdAt: { gte: from, lt: to } } }),
    ]);
    const completed = appts.filter((a) => a.status === 'COMPLETED');
    const earned = completed.reduce((s, a) => s + a.priceMinor - a.discountMinor, 0);
    const sumKind = (k: string) => payments.filter((p) => p.kind === k).reduce((s, p) => s + p.amountMinor, 0);
    const expensesTotal = expenses.reduce((s, e) => s + e.amountMinor, 0);
    const group = <T extends string>(key: (a: (typeof completed)[number]) => T) => {
      const m = new Map<T, number>();
      for (const a of completed) m.set(key(a), (m.get(key(a)) ?? 0) + a.priceMinor - a.discountMinor);
      return [...m.entries()].map(([name, amountMinor]) => ({ name, amountMinor })).sort((x, y) => y.amountMinor - x.amountMinor);
    };
    // revenue by service: allocate the appointment discount proportionally to service prices
    const byService = new Map<string, number>();
    for (const a of completed) {
      for (const s of a.services) {
        const share = a.priceMinor > 0 ? Math.round((s.priceMinor * (a.priceMinor - a.discountMinor)) / a.priceMinor) : 0;
        byService.set(s.nameSnapshot, (byService.get(s.nameSnapshot) ?? 0) + share);
      }
    }
    const daily = new Map<string, number>();
    for (const a of completed) {
      const d = DateTime.fromJSDate(a.startsAt, { zone: b.timezone }).toISODate()!;
      daily.set(d, (daily.get(d) ?? 0) + a.priceMinor - a.discountMinor);
    }
    const decided = appts.filter((a) => ['COMPLETED', 'NO_SHOW'].includes(a.status)).length;
    const clientIds = completed.map((a) => a.clientId).filter((x): x is string => !!x);
    const returning = clientIds.length
      ? await this.prisma.appointment.groupBy({ by: ['clientId'], where: { businessId, clientId: { in: clientIds }, status: 'COMPLETED', startsAt: { lt: from } } })
      : [];
    return {
      currency: b.currency, from: fromDate, to: toDate,
      earnedRevenueMinor: earned,
      cashFlow: { depositsMinor: sumKind('DEPOSIT'), paymentsMinor: sumKind('PAYMENT'), refundsMinor: sumKind('REFUND'), netMinor: sumKind('DEPOSIT') + sumKind('PAYMENT') - sumKind('REFUND') },
      expensesMinor: expensesTotal,
      profitEstimateMinor: earned - expensesTotal,
      appointments: {
        total: appts.length, completed: completed.length,
        cancelled: appts.filter((a) => a.status === 'CANCELLED').length,
        noShow: appts.filter((a) => a.status === 'NO_SHOW').length,
        noShowRate: decided ? appts.filter((a) => a.status === 'NO_SHOW').length / decided : 0,
        averageTicketMinor: completed.length ? Math.round(earned / completed.length) : 0,
      },
      clients: { new: newClients, served: new Set(clientIds).size, returning: returning.length },
      byService: [...byService.entries()].map(([name, amountMinor]) => ({ name, amountMinor })).sort((x, y) => y.amountMinor - x.amountMinor),
      byEmployee: group((a) => a.employee.displayName),
      byLocation: group((a) => a.location.name),
      daily: [...daily.entries()].sort().map(([date, amountMinor]) => ({ date, amountMinor })),
      expensesByCategory: Object.entries(expenses.reduce<Record<string, number>>((m, e) => ({ ...m, [e.category]: (m[e.category] ?? 0) + e.amountMinor }), {})).map(([name, amountMinor]) => ({ name, amountMinor })),
    };
  }
}
