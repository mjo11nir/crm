import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DateTime } from 'luxon';
import { parseCsv, toCsv } from '../common/csv';
import { normalizePhone } from '../common/phone';
import { PrismaService } from '../common/prisma.service';
import { ClientDto, UpdateClientDto } from './clients.dto';

const toDate = (s?: string) => (s ? new Date(`${s}T00:00:00Z`) : undefined);

@Injectable()
export class ClientsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(businessId: string, opts: { q?: string; archived?: boolean; tag?: string; take?: number; skip?: number }) {
    const where: Prisma.ClientWhereInput = {
      businessId,
      archivedAt: opts.archived ? { not: null } : null,
      ...(opts.tag ? { tags: { has: opts.tag } } : {}),
    };
    if (opts.q?.trim()) {
      const q = opts.q.trim();
      const digits = normalizePhone(q);
      where.OR = [
        { fullName: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        ...(digits ? [{ phoneNormalized: { contains: digits } }] : []),
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.client.findMany({ where, orderBy: { fullName: 'asc' }, take: Math.min(opts.take ?? 50, 200), skip: opts.skip ?? 0 }),
      this.prisma.client.count({ where }),
    ]);
    return { items, total };
  }

  create(businessId: string, dto: ClientDto) {
    return this.prisma.client.create({
      data: { ...dto, birthday: toDate(dto.birthday), phoneNormalized: normalizePhone(dto.phone), businessId },
    });
  }

  async update(businessId: string, id: string, dto: UpdateClientDto) {
    await this.get(businessId, id);
    return this.prisma.client.update({
      where: { id },
      data: { ...dto, birthday: toDate(dto.birthday), ...(dto.phone !== undefined ? { phoneNormalized: normalizePhone(dto.phone) } : {}) },
    });
  }

  async get(businessId: string, id: string) {
    const c = await this.prisma.client.findFirst({ where: { id, businessId } });
    if (!c) throw new NotFoundException('Client not found');
    return c;
  }

  /** Full profile: visit history, spending (completed appts net), payments, next appointment. */
  async profile(businessId: string, id: string) {
    const client = await this.get(businessId, id);
    const now = new Date();
    const [appointments, payments] = await Promise.all([
      this.prisma.appointment.findMany({ where: { businessId, clientId: id }, include: { services: true }, orderBy: { startsAt: 'desc' }, take: 200 }),
      this.prisma.payment.findMany({ where: { businessId, clientId: id }, orderBy: { paidAt: 'desc' }, take: 200 }),
    ]);
    const completed = appointments.filter((a) => a.status === 'COMPLETED');
    const next = appointments.filter((a) => a.startsAt > now && (a.status === 'BOOKED' || a.status === 'CONFIRMED')).at(-1) ?? null;
    return {
      client,
      stats: {
        visits: completed.length,
        totalSpentMinor: completed.reduce((s, a) => s + a.priceMinor - a.discountMinor, 0),
        lastVisit: completed[0]?.startsAt ?? null,
        nextAppointment: next,
        noShows: appointments.filter((a) => a.status === 'NO_SHOW').length,
        cancellations: appointments.filter((a) => a.status === 'CANCELLED').length,
      },
      appointments,
      payments,
    };
  }

  async archive(businessId: string, id: string, archived: boolean) {
    await this.get(businessId, id);
    return this.prisma.client.update({ where: { id }, data: { archivedAt: archived ? new Date() : null } });
  }

  /** Potential duplicates: same normalised phone or same case-insensitive full name. */
  async duplicates(businessId: string) {
    const rows = await this.prisma.$queryRaw<{ key: string; ids: string[] }[]>`
      SELECT key, array_agg(id::text ORDER BY "createdAt") AS ids FROM (
        SELECT id, "createdAt", 'phone:' || "phoneNormalized" AS key FROM clients
          WHERE "businessId" = ${businessId}::uuid AND "archivedAt" IS NULL AND "phoneNormalized" IS NOT NULL
        UNION ALL
        SELECT id, "createdAt", 'name:' || lower(trim("fullName")) FROM clients
          WHERE "businessId" = ${businessId}::uuid AND "archivedAt" IS NULL
      ) t GROUP BY key HAVING count(*) > 1`;
    return rows;
  }

  /** Merge source into target: moves history, unions tags, archives source. */
  async merge(businessId: string, sourceId: string, targetId: string) {
    if (sourceId === targetId) throw new BadRequestException('Cannot merge a client into itself');
    const [source, target] = await Promise.all([this.get(businessId, sourceId), this.get(businessId, targetId)]);
    await this.prisma.$transaction([
      this.prisma.appointment.updateMany({ where: { businessId, clientId: sourceId }, data: { clientId: targetId } }),
      this.prisma.payment.updateMany({ where: { businessId, clientId: sourceId }, data: { clientId: targetId } }),
      this.prisma.waitlistEntry.updateMany({ where: { businessId, clientId: sourceId }, data: { clientId: targetId } }),
      this.prisma.client.update({
        where: { id: targetId },
        data: {
          tags: [...new Set([...target.tags, ...source.tags])],
          phone: target.phone ?? source.phone, phoneNormalized: target.phoneNormalized ?? source.phoneNormalized,
          email: target.email ?? source.email, birthday: target.birthday ?? source.birthday,
          notes: [target.notes, source.notes].filter(Boolean).join('\n---\n') || null,
        },
      }),
      this.prisma.client.update({ where: { id: sourceId }, data: { archivedAt: new Date() } }),
    ]);
    return this.get(businessId, targetId);
  }

  async exportCsv(businessId: string) {
    const clients = await this.prisma.client.findMany({ where: { businessId }, orderBy: { fullName: 'asc' } });
    return toCsv(
      ['fullName', 'phone', 'email', 'birthday', 'tags', 'notes', 'marketingConsent', 'archived'],
      clients.map((c) => [c.fullName, c.phone, c.email, c.birthday?.toISOString().slice(0, 10), c.tags.join('|'), c.notes, c.marketingConsent, c.archivedAt ? 'yes' : '']),
    );
  }

  async importCsv(businessId: string, csv: string) {
    const rows = parseCsv(csv);
    if (rows.length < 2) throw new BadRequestException('CSV must contain a header and at least one row');
    const header = rows[0].map((h) => h.trim().toLowerCase());
    const idx = (n: string) => header.indexOf(n.toLowerCase());
    if (idx('fullname') < 0) throw new BadRequestException('Missing fullName column');
    if (rows.length > 20_001) throw new BadRequestException('Max 20000 rows per import');
    const existing = new Set(
      (await this.prisma.client.findMany({ where: { businessId, phoneNormalized: { not: null } }, select: { phoneNormalized: true } })).map((c) => c.phoneNormalized),
    );
    const errors: { row: number; error: string }[] = [];
    const data: Prisma.ClientCreateManyInput[] = [];
    let skipped = 0;
    rows.slice(1).forEach((r, i) => {
      const get = (n: string) => (idx(n) >= 0 ? r[idx(n)]?.trim() || undefined : undefined);
      const fullName = get('fullName');
      if (!fullName) return errors.push({ row: i + 2, error: 'fullName is required' });
      const phoneNormalized = normalizePhone(get('phone'));
      if (phoneNormalized && existing.has(phoneNormalized)) { skipped++; return; }
      const birthday = get('birthday');
      if (birthday && !DateTime.fromISO(birthday).isValid) return errors.push({ row: i + 2, error: 'birthday must be YYYY-MM-DD' });
      if (phoneNormalized) existing.add(phoneNormalized);
      data.push({ businessId, fullName: fullName.slice(0, 160), phone: get('phone'), phoneNormalized, email: get('email'), birthday: toDate(birthday), notes: get('notes') });
    });
    const created = data.length ? (await this.prisma.client.createMany({ data })).count : 0;
    return { created, skippedDuplicates: skipped, errors };
  }
}
