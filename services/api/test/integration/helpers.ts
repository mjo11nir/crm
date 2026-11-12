import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { DateTime } from 'luxon';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/app.factory';
import { PrismaService } from '../../src/common/prisma.service';

export async function bootApp() {
  const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = mod.createNestApplication({ logger: false });
  configureApp(app);
  await app.init();
  const prisma = app.get(PrismaService);
  return { app, prisma };
}

export async function resetDb(prisma: PrismaService) {
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename <> '_prisma_migrations'`;
  await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map((t) => `"${t.tablename}"`).join(',')} CASCADE`);
}

let n = 0;
export async function registerOwner(app: INestApplication, overrides: Record<string, unknown> = {}) {
  n++;
  const email = `owner${n}-${Date.now()}@example.test`;
  const res = await request(app.getHttpServer()).post('/api/v1/auth/register').send({
    email, password: 'Secret123!', fullName: `Owner ${n}`, businessName: `Studio ${n}`, timezone: 'Europe/Istanbul', currency: 'EUR', phone: '+90 500 000 00 0' + (n % 10), ...overrides,
  });
  if (res.status !== 201) throw new Error(`register failed ${res.status} ${JSON.stringify(res.body)}`);
  const me = await request(app.getHttpServer()).get('/api/v1/auth/me').set('Authorization', `Bearer ${res.body.accessToken}`);
  const business = me.body.memberships[0].business;
  return { email, password: 'Secret123!', token: res.body.accessToken as string, refreshToken: res.body.refreshToken as string, businessId: business.id as string, slug: business.slug as string };
}

/** A local (Europe/Istanbul) date string for the given ISO weekday at least `minDays` ahead. */
export function upcoming(weekday: number, minDays = 7): string {
  let d = DateTime.now().setZone('Europe/Istanbul').plus({ days: minDays }).startOf('day');
  while (d.weekday !== weekday) d = d.plus({ days: 1 });
  return d.toISODate()!;
}

export function at(date: string, hhmm: string): string {
  return DateTime.fromISO(`${date}T${hhmm}`, { zone: 'Europe/Istanbul' }).toUTC().toISO()!;
}

export function api(app: INestApplication, token?: string) {
  const s = request(app.getHttpServer());
  const wrap = (m: 'get' | 'post' | 'patch' | 'put' | 'delete') => (url: string) => {
    const r = s[m](`/api/v1${url}`);
    return token ? r.set('Authorization', `Bearer ${token}`) : r;
  };
  return { get: wrap('get'), post: wrap('post'), patch: wrap('patch'), put: wrap('put'), delete: wrap('delete') };
}
