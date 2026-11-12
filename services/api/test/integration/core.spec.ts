import { INestApplication } from '@nestjs/common';
import { PrismaService } from '../../src/common/prisma.service';
import { NotificationsService } from '../../src/notifications/notifications.service';
import { DELIVERY_ADAPTER, SandboxAdapter } from '../../src/notifications/adapters';
import { api, at, bootApp, registerOwner, resetDb, upcoming } from './helpers';

let app: INestApplication;
let prisma: PrismaService;

beforeAll(async () => {
  ({ app, prisma } = await bootApp());
  await resetDb(prisma);
});
afterAll(async () => app.close());

describe('auth', () => {
  it('registers, logs in, rotates refresh tokens and detects reuse', async () => {
    const o = await registerOwner(app);
    const login = await api(app).post('/auth/login').send({ email: o.email, password: o.password });
    expect(login.status).toBe(200);
    const bad = await api(app).post('/auth/login').send({ email: o.email, password: 'wrong-password' });
    expect(bad.status).toBe(401);

    const r1 = await api(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
    expect(r1.status).toBe(200);
    // replaying the old token = reuse -> rejected and family revoked
    const replay = await api(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
    expect(replay.status).toBe(401);
    const afterRevoke = await api(app).post('/auth/refresh').send({ refreshToken: r1.body.refreshToken });
    expect(afterRevoke.status).toBe(401);
  });

  it('rejects duplicate email, weak password, missing token', async () => {
    const o = await registerOwner(app);
    expect((await api(app).post('/auth/register').send({ email: o.email, password: 'Secret123!', fullName: 'x', businessName: 'y' })).status).toBe(409);
    expect((await api(app).post('/auth/register').send({ email: 'a@b.test', password: 'short', fullName: 'x', businessName: 'y' })).status).toBe(400);
    expect((await api(app).get('/auth/me')).status).toBe(401);
    expect((await api(app, 'garbage').get('/auth/me')).status).toBe(401);
  });

  it('logout-all revokes every refresh token', async () => {
    const o = await registerOwner(app);
    expect((await api(app, o.token).post('/auth/logout-all')).status).toBe(204);
    expect((await api(app).post('/auth/refresh').send({ refreshToken: o.refreshToken })).status).toBe(401);
  });

  it('deletes account and all owned tenant data', async () => {
    const o = await registerOwner(app);
    await api(app, o.token).post(`/businesses/${o.businessId}/clients`).send({ fullName: 'To be erased' });
    expect((await api(app, o.token).delete('/auth/account').send({ password: o.password })).status).toBe(204);
    expect(await prisma.business.findUnique({ where: { id: o.businessId } })).toBeNull();
    expect(await prisma.client.count({ where: { businessId: o.businessId } })).toBe(0);
  });
});

describe('tenant isolation', () => {
  it('a user can never read or modify another business data', async () => {
    const a = await registerOwner(app);
    const b = await registerOwner(app);
    const client = await api(app, a.token).post(`/businesses/${a.businessId}/clients`).send({ fullName: 'Private Client' });
    expect(client.status).toBe(201);
    expect((await api(app, b.token).get(`/businesses/${a.businessId}/clients`)).status).toBe(403);
    expect((await api(app, b.token).get(`/businesses/${a.businessId}/clients/${client.body.id}`)).status).toBe(403);
    // using own business id with someone else's record id -> 404, never the record
    expect((await api(app, b.token).get(`/businesses/${b.businessId}/clients/${client.body.id}`)).status).toBe(404);
    expect((await api(app, b.token).patch(`/businesses/${b.businessId}/clients/${client.body.id}`).send({ fullName: 'hacked' })).status).toBe(404);
    const list = await api(app, b.token).get(`/businesses/${b.businessId}/clients`);
    expect(list.body.items.find((c: { id: string }) => c.id === client.body.id)).toBeUndefined();
  });

  it('employee role cannot change business settings', async () => {
    const a = await registerOwner(app);
    const emp = await registerOwner(app);
    await prisma.businessMember.create({ data: { businessId: a.businessId, userId: (await prisma.user.findUniqueOrThrow({ where: { email: emp.email } })).id, role: 'EMPLOYEE' } });
    expect((await api(app, emp.token).patch(`/businesses/${a.businessId}`).send({ name: 'x' })).status).toBe(403);
    expect((await api(app, emp.token).get(`/businesses/${a.businessId}/clients`)).status).toBe(200);
    expect((await api(app, emp.token).get(`/businesses/${a.businessId}/finance/report?from=2026-11-01&to=2026-11-30`)).status).toBe(403);
  });
});

describe('clients', () => {
  it('CRUD, search, archive, duplicates, merge, CSV import/export', async () => {
    const o = await registerOwner(app);
    const c = api(app, o.token);
    const base = `/businesses/${o.businessId}/clients`;
    const anna = (await c.post(base).send({ fullName: 'Анна Иванова', phone: '+90 533 111 22 33', tags: ['vip'], birthday: '1990-05-01' })).body;
    expect(anna.phoneNormalized).toBe('905331112233');
    expect((await c.post(base).send({ fullName: '' })).status).toBe(400);
    expect((await c.post(base).send({ fullName: 'X', email: 'not-an-email' })).status).toBe(400);
    const dup = (await c.post(base).send({ fullName: 'Anna I.', phone: '905331112233', tags: ['new'] })).body;
    expect((await c.get(`${base}?q=анна`)).body.total).toBe(1);
    expect((await c.get(`${base}?q=1112233`)).body.total).toBe(2);
    expect((await c.get(`${base}?tag=vip`)).body.total).toBe(1);

    const dups = (await c.get(`${base}/duplicates`)).body;
    expect(dups.find((d: { key: string }) => d.key === 'phone:905331112233').ids).toHaveLength(2);
    const merged = (await c.post(`${base}/merge`).send({ sourceId: dup.id, targetId: anna.id })).body;
    expect(merged.tags.sort()).toEqual(['new', 'vip']);
    expect((await c.get(`${base}?q=1112233`)).body.total).toBe(1);

    await c.post(`${base}/${anna.id}/archive`);
    expect((await c.get(base)).body.total).toBe(0);
    expect((await c.get(`${base}?archived=true`)).body.total).toBe(2);
    await c.post(`${base}/${anna.id}/unarchive`);

    const imp = await c.post(`${base}/import`).send({ csv: 'fullName,phone,email,birthday\n"Ivanova, Maria",+905550001111,m@x.test,1992-02-03\nNo Phone,,,\n,123456789,,\nDup,+90 533 111 22 33,,\nBad Date,+905550009999,,notadate\n' });
    expect(imp.status).toBe(201);
    expect(imp.body).toMatchObject({ created: 2, skippedDuplicates: 1 });
    expect(imp.body.errors).toHaveLength(2);
    const csv = await c.get(`${base}/export.csv`);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(csv.text).toContain('"Ivanova, Maria"');
  });
});

async function setupCatalog(o: { token: string; businessId: string }) {
  const c = api(app, o.token);
  const svc = (await c.post(`/businesses/${o.businessId}/services`).send({ name: 'Маникюр с однотонным покрытием', durationMinutes: 120, priceMinor: 4500 })).body;
  const client = (await c.post(`/businesses/${o.businessId}/clients`).send({ fullName: 'Мама Халиде', phone: '+90 533 222 33 44' })).body;
  return { c, svc, client };
}

describe('appointments', () => {
  it('creates, lists, reschedules, completes, cancels with history and conflicts', async () => {
    const o = await registerOwner(app);
    const { c, svc, client } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(2);

    const a1 = await c.post(`${B}/appointments`).send({ clientId: client.id, serviceIds: [svc.id], startsAt: at(day, '09:00') });
    expect(a1.status).toBe(201);
    expect(a1.body).toMatchObject({ status: 'BOOKED', priceMinor: 4500, netPriceMinor: 4500, balanceMinor: 4500 });
    expect(new Date(a1.body.endsAt).getTime() - new Date(a1.body.startsAt).getTime()).toBe(120 * 60_000);

    // overlapping -> 409
    const overlap = await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '10:00') });
    expect(overlap.status).toBe(409);
    expect(overlap.body.code).toBe('SLOT_TAKEN');
    // outside working hours -> 409 unless explicitly allowed
    expect((await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '18:00') })).status).toBe(409);
    expect((await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '19:00'), allowOutsideHours: true })).status).toBe(201);

    // day view: revenue + free gaps
    const dv = (await c.get(`${B}/calendar/day?date=${day}`)).body;
    expect(dv.appointments).toHaveLength(2);
    expect(dv.freeGaps[0].minutes).toBe(480); // 11:00–19:00
    expect(dv.revenueMinor).toBe(9000);

    // reschedule with optimistic concurrency
    const moved = await c.patch(`${B}/appointments/${a1.body.id}`).send({ version: 1, startsAt: at(day, '13:00') });
    expect(moved.status).toBe(200);
    expect(moved.body.version).toBe(2);
    const stale = await c.patch(`${B}/appointments/${a1.body.id}`).send({ version: 1, startsAt: at(day, '15:00') });
    expect(stale.status).toBe(409);
    expect(stale.body.code).toBe('VERSION_CONFLICT');

    // discount
    const disc = await c.patch(`${B}/appointments/${a1.body.id}`).send({ version: 2, discountPercent: 10 });
    expect(disc.body.netPriceMinor).toBe(4050);

    // status transitions
    expect((await c.post(`${B}/appointments/${a1.body.id}/status`).send({ status: 'COMPLETED' })).body.status).toBe('COMPLETED');
    const cancelled = await c.post(`${B}/appointments/${a1.body.id}/status`).send({ status: 'CANCELLED' });
    expect(cancelled.status).toBe(400); // completed cannot be cancelled directly
    const a2 = (await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '09:00') })).body;
    expect((await c.post(`${B}/appointments/${a2.id}/status`).send({ status: 'CANCELLED' })).body.status).toBe('CANCELLED');
    // the cancelled slot is free again
    expect((await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '09:00') })).status).toBe(201);
    const full = (await c.get(`${B}/appointments/${a1.body.id}`)).body;
    expect(full.history.map((h: { toStatus: string }) => h.toStatus)).toEqual(['BOOKED', 'COMPLETED']);
  });

  it('creates weekly recurring appointments and reports conflicts', async () => {
    const o = await registerOwner(app);
    const { c, svc } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(3);
    const blocker = await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(upcoming(3, 14), '11:00') });
    expect(blocker.status).toBe(201);
    const r = await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '11:00'), recurrence: { everyWeeks: 1, count: 4 } });
    expect(r.status).toBe(201);
    expect(r.body.created.length + r.body.conflicts.length).toBe(4);
    expect(r.body.conflicts.length).toBeGreaterThanOrEqual(1);
  });

  it('never double-books under 10 concurrent requests for the same slot', async () => {
    const o = await registerOwner(app);
    const { c, svc } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const start = at(upcoming(4), '13:00');
    const results = await Promise.all(Array.from({ length: 10 }, () => c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: start })));
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.filter((r) => r.status === 409)).toHaveLength(9);
    expect(await prisma.appointment.count({ where: { businessId: o.businessId } })).toBe(1);
  });
});

describe('public online booking', () => {
  it('shows info, real slots, books atomically & idempotently', async () => {
    const o = await registerOwner(app);
    const { svc } = await setupCatalog(o);
    const pub = api(app);
    const info = await pub.get(`/public/${o.slug}`);
    expect(info.status).toBe(200);
    expect(info.body.services).toHaveLength(1);
    expect(info.body.business.name).toBeDefined();
    expect(info.body).not.toHaveProperty('clients');

    const day = upcoming(1);
    const av = (await pub.get(`/public/${o.slug}/availability?from=${day}&to=${day}&serviceIds=${svc.id}`)).body;
    const slot = av.days[0].slots[0];
    expect(slot.localTime).toBe('09:00');

    const body = { serviceIds: [svc.id], startsAt: new Date(slot.start).toISOString(), client: { fullName: 'Online Client', phone: '+90 555 777 88 99' }, acceptPolicy: true };
    expect((await pub.post(`/public/${o.slug}/bookings`).send(body)).status).toBe(400); // missing key
    expect((await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000001').send({ ...body, acceptPolicy: false })).status).toBe(400);
    const r1 = await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000002').send(body);
    expect(r1.status).toBe(201);
    expect(r1.body.status).toBe('CONFIRMED');
    const r2 = await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000002').send(body);
    expect(r2.status).toBe(201);
    expect(r2.body.bookingId).toBe(r1.body.bookingId); // replay returns same booking
    const mismatch = await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000002').send({ ...body, client: { ...body.client, fullName: 'Other' } });
    expect(mismatch.status).toBe(409);
    // a different client trying the same slot -> 409
    const taken = await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000003').send({ ...body, client: { fullName: 'Another', phone: '+90 555 000 11 22' } });
    expect(taken.status).toBe(409);
    expect(taken.body.code).toBe('SLOT_TAKEN');
    // unaligned start or past slot is rejected even if free
    const unaligned = new Date(new Date(slot.start).getTime() + 7 * 60_000 + 4 * 3_600_000).toISOString();
    expect((await pub.post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'k-0000000000000004').send({ ...body, startsAt: unaligned })).status).toBe(409);
    // slot disappears from availability
    const av2 = (await pub.get(`/public/${o.slug}/availability?from=${day}&to=${day}&serviceIds=${svc.id}`)).body;
    expect(av2.days[0].slots.find((s: { localTime: string }) => s.localTime === '09:00')).toBeUndefined();
    // client was created and linked by phone
    const client = await prisma.client.findFirst({ where: { businessId: (await prisma.business.findUniqueOrThrow({ where: { slug: o.slug } })).id, phoneNormalized: '905557778899' } });
    expect(client).not.toBeNull();
  });

  it('concurrent public bookings for one slot produce exactly one booking', async () => {
    const o = await registerOwner(app);
    const { svc } = await setupCatalog(o);
    const day = upcoming(5);
    const start = at(day, '15:00');
    const results = await Promise.all(Array.from({ length: 8 }, (_, i) =>
      api(app).post(`/public/${o.slug}/bookings`).set('Idempotency-Key', `concurrent-key-${String(i).padStart(4, '0')}`)
        .send({ serviceIds: [svc.id], startsAt: start, client: { fullName: `Client ${i}`, phone: `+90555000${String(i).padStart(4, '0')}` }, acceptPolicy: true })));
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.map((r) => r.status === 201 || r.status === 409 ? 'ok' : `${r.status} ${JSON.stringify(r.body)}`).filter((x) => x !== 'ok')).toEqual([]);
  });

  it('rejects deposit-required services (no verified payment provider) and disabled pages', async () => {
    const o = await registerOwner(app);
    const c = api(app, o.token);
    const svc = (await c.post(`/businesses/${o.businessId}/services`).send({ name: 'Deposit svc', durationMinutes: 60, priceMinor: 5000, depositMinor: 1000 })).body;
    const r = await api(app).post(`/public/${o.slug}/bookings`).set('Idempotency-Key', 'deposit-key-000001')
      .send({ serviceIds: [svc.id], startsAt: at(upcoming(1), '09:00'), client: { fullName: 'Dep', phone: '+905550001234' }, acceptPolicy: true });
    expect(r.status).toBe(409);
    expect(r.body.code).toBe('DEPOSIT_PROVIDER_UNAVAILABLE');
    await c.patch(`/businesses/${o.businessId}`).send({ onlineBookingEnabled: false });
    expect((await api(app).get(`/public/${o.slug}`)).status).toBe(404);
  });
});

describe('payments & finance', () => {
  it('records deposit + final payment, prevents overpayment, refunds, reports without double counting', async () => {
    const o = await registerOwner(app);
    const { c, svc, client } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(1);
    const a = (await c.post(`${B}/appointments`).send({ clientId: client.id, serviceIds: [svc.id], startsAt: at(day, '09:00') })).body;
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'DEPOSIT', method: 'CASH', amountMinor: 1000 })).body.balanceMinor).toBe(3500);
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'PAYMENT', method: 'CARD', amountMinor: 4000 })).status).toBe(400);
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'PAYMENT', method: 'ONLINE', amountMinor: 100 })).status).toBe(400);
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'PAYMENT', method: 'CARD', amountMinor: 3500 })).body.balanceMinor).toBe(0);
    await c.post(`${B}/appointments/${a.id}/status`).send({ status: 'COMPLETED' });
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'REFUND', method: 'CARD', amountMinor: 5000 })).status).toBe(400);
    expect((await c.post(`${B}/appointments/${a.id}/payments`).send({ kind: 'REFUND', method: 'CARD', amountMinor: 500 })).body.balanceMinor).toBe(500);
    await c.post(`${B}/expenses`).send({ category: 'Материалы', amountMinor: 1200, spentAt: at(day, '12:00') });

    const today = new Date().toISOString().slice(0, 10);
    const rep = (await c.get(`${B}/finance/report?from=${today}&to=${day}`)).body;
    expect(rep.earnedRevenueMinor).toBe(4500); // from the appointment, not from payments
    expect(rep.cashFlow).toEqual({ depositsMinor: 1000, paymentsMinor: 3500, refundsMinor: 500, netMinor: 4000 });
    expect(rep.expensesMinor).toBe(1200);
    expect(rep.profitEstimateMinor).toBe(3300);
    expect(rep.byService[0]).toEqual({ name: svc.name, amountMinor: 4500 });
    expect(rep.appointments.averageTicketMinor).toBe(4500);
    // CSV export is a VIP feature (trial -> 402)
    expect((await c.get(`${B}/finance/report.csv?from=${today}&to=${day}`)).status).toBe(402);
  });
});

describe('dashboard & free slots', () => {
  it('computes live dashboard values', async () => {
    const o = await registerOwner(app);
    const { c, svc, client } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(2);
    await c.post(`${B}/appointments`).send({ clientId: client.id, serviceIds: [svc.id], startsAt: at(day, '09:00') });
    const x = (await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '13:00') })).body;
    await c.post(`${B}/appointments/${x.id}/status`).send({ status: 'CANCELLED' });
    const d = (await c.get(`${B}/dashboard?date=${day}`)).body;
    expect(d.selectedDate).toBe(day);
    expect(d.week).toHaveLength(7);
    expect(d.week.find((w: { date: string }) => w.date === day).count).toBe(1);
    expect(d.appointments).toHaveLength(1);
    expect(d.appointments[0]).toMatchObject({ clientName: 'Мама Халиде', netPriceMinor: 4500 });
    expect(d.dayRevenueMinor).toBe(4500);
    expect(d.clients.total).toBe(1);
    expect(d.subscription).toMatchObject({ tier: 'TRIAL', status: 'ACTIVE' });
  });

  it('free-slot card reflects real bookings', async () => {
    const o = await registerOwner(app);
    const { c, svc } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(3);
    await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '09:00') });
    const fs = (await c.get(`${B}/free-slots?from=${day}&to=${day}&serviceId=${svc.id}`)).body;
    expect(fs.days).toEqual([{ date: day, times: ['11:00', '13:00', '15:00', '17:00'] }]);
    expect(fs.card.name).toBeDefined();
    expect(fs.bookingUrl).toContain(o.slug);
  });
});

describe('subscription enforcement', () => {
  it('expired trial blocks writes (402) but keeps reads', async () => {
    const o = await registerOwner(app);
    await prisma.subscription.update({ where: { businessId: o.businessId }, data: { expiresAt: new Date(Date.now() - 1000) } });
    const c = api(app, o.token);
    const w = await c.post(`/businesses/${o.businessId}/clients`).send({ fullName: 'Blocked' });
    expect(w.status).toBe(402);
    expect(w.body.code).toBe('SUBSCRIPTION_REQUIRED');
    expect((await c.get(`/businesses/${o.businessId}/clients`)).status).toBe(200);
    expect((await c.get(`/businesses/${o.businessId}/subscription`)).body.status).toBe('EXPIRED');
    expect((await api(app).get(`/public/${o.slug}`)).status).toBe(404); // online booking disabled
  });
});

describe('notifications & waitlist', () => {
  it('queues confirmation + reminder once, delivers via sandbox with retry and dead-letter', async () => {
    const o = await registerOwner(app);
    const { c, svc, client } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const a = (await c.post(`${B}/appointments`).send({ clientId: client.id, serviceIds: [svc.id], startsAt: at(upcoming(2), '09:00') })).body;
    const jobs = await prisma.notificationJob.findMany({ where: { businessId: o.businessId } });
    expect(jobs.map((j) => j.template).sort()).toEqual(['appointment_reminder', 'booking_confirmation']);
    // isolate the queue from jobs created by other tests
    await prisma.notificationJob.updateMany({ where: { NOT: { businessId: o.businessId }, status: 'QUEUED' }, data: { status: 'SENT' } });
    const svcN = app.get(NotificationsService);
    const adapter = app.get<SandboxAdapter>(DELIVERY_ADAPTER);
    adapter.failNext = 1;
    const first = await svcN.processDue();
    expect(first.failed).toBeGreaterThanOrEqual(1);
    await prisma.notificationJob.updateMany({ where: { businessId: o.businessId, status: 'QUEUED', template: 'booking_confirmation' }, data: { scheduledFor: new Date(0) } });
    await svcN.processDue();
    const confirm = await prisma.notificationJob.findUniqueOrThrow({ where: { dedupeKey: `confirm:${a.id}` } });
    expect(confirm.status).toBe('SENT');
    expect(confirm.attempts).toBe(2);
    // cancelling cancels the pending reminder
    await c.post(`${B}/appointments/${a.id}/status`).send({ status: 'CANCELLED' });
    expect((await prisma.notificationJob.findUniqueOrThrow({ where: { dedupeKey: `reminder:${a.id}` } })).status).toBe('FAILED');
  });

  it('released slot is offered to exactly one waitlist entry', async () => {
    const o = await registerOwner(app);
    const { c, svc, client } = await setupCatalog(o);
    const B = `/businesses/${o.businessId}`;
    const day = upcoming(4);
    const other = (await c.post(`${B}/clients`).send({ fullName: 'Waiting 2', phone: '+905550004444' })).body;
    const w1 = (await c.post(`${B}/waitlist`).send({ clientId: client.id, serviceId: svc.id, preferredFrom: day, preferredTo: day, priority: 5 })).body;
    const w2 = (await c.post(`${B}/waitlist`).send({ clientId: other.id, serviceId: svc.id, preferredFrom: day, preferredTo: day })).body;
    const a = (await c.post(`${B}/appointments`).send({ serviceIds: [svc.id], startsAt: at(day, '11:00') })).body;
    await c.post(`${B}/appointments/${a.id}/status`).send({ status: 'CANCELLED' });
    const entries = await prisma.waitlistEntry.findMany({ where: { id: { in: [w1.id, w2.id] } } });
    expect(entries.find((e) => e.id === w1.id)!.status).toBe('OFFERED');
    expect(entries.find((e) => e.id === w2.id)!.status).toBe('WAITING');
    expect(await prisma.notificationJob.count({ where: { businessId: o.businessId, template: 'waitlist_offer' } })).toBe(1);
  });
});

describe('settings & chats', () => {
  it('updates schedule, exceptions and booking rules; validates input', async () => {
    const o = await registerOwner(app);
    const c = api(app, o.token);
    const B = `/businesses/${o.businessId}`;
    const biz = (await c.get(B)).body;
    const emp = biz.employees[0];
    const loc = biz.locations[0];
    expect((await c.put(`${B}/employees/${emp.id}/schedule`).send({ days: [{ weekday: 6, startMinute: 600, endMinute: 900, breakStartMinute: 720, breakEndMinute: 780, locationId: loc.id }] })).status).toBe(200);
    expect((await c.put(`${B}/employees/${emp.id}/schedule`).send({ days: [{ weekday: 6, startMinute: 900, endMinute: 600, locationId: loc.id }] })).status).toBe(400);
    const sat = upcoming(6);
    await c.post(`${B}/services`).send({ name: 'S', durationMinutes: 60, priceMinor: 1000 });
    const av = (await c.get(`${B}/availability?from=${sat}&to=${sat}&duration=60`)).body;
    expect(av.days[0].slots.map((s: { localTime: string }) => s.localTime)).toEqual(expect.arrayContaining(['10:00', '13:00']));
    expect(av.days[0].slots.map((s: { localTime: string }) => s.localTime)).not.toContain('12:00');
    await c.put(`${B}/employees/${emp.id}/exceptions`).send({ date: sat, isClosed: true });
    expect((await c.get(`${B}/availability?from=${sat}&to=${sat}&duration=60`)).body.days[0].reason).toBe('DAY_OFF');
    expect((await c.patch(B).send({ timezone: 'Mars/Olympus' })).status).toBe(400);
    expect((await c.patch(B).send({ minNoticeMinutes: 120, unknownField: 1 })).status).toBe(400);
    expect((await c.patch(B).send({ minNoticeMinutes: 120 })).body.minNoticeMinutes).toBe(120);
  });

  it('internal chat with unread counts', async () => {
    const o = await registerOwner(app);
    const c = api(app, o.token);
    const B = `/businesses/${o.businessId}`;
    const conv = (await c.post(`${B}/conversations`).send({ title: 'Поддержка', kind: 'SUPPORT' })).body;
    await c.post(`${B}/conversations/${conv.id}/messages`).send({ body: 'Здравствуйте' });
    await prisma.message.create({ data: { conversationId: conv.id, body: 'Ответ поддержки', senderUserId: null } });
    expect((await c.get(`${B}/conversations`)).body[0].unread).toBe(1);
    expect((await c.get(`${B}/conversations/${conv.id}/messages`)).body).toHaveLength(2);
    expect((await c.get(`${B}/conversations`)).body[0].unread).toBe(0);
  });
});
