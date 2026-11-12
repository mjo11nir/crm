// E2E: a client books online through the public booking site; the booking must appear in
// the business calendar (API) and the slot must disappear for the next visitor.
// Requires: API on :3000 with seeded data (pnpm db:seed), booking-web on :3001.
//   node tests/e2e/public-booking.e2e.mjs
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const WEB = process.env.WEB_URL ?? 'http://localhost:3001';
const API = process.env.API_URL ?? 'http://localhost:3000/api/v1';
const SLUG = process.env.SLUG ?? 'lavanda-studio';

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.goto(`${WEB}/${SLUG}`);
  await page.getByRole('button', { name: /Маникюр с однотонным покрытием/ }).click();
  const firstSlot = page.getByRole('group', { name: 'Время' }).getByRole('button').first();
  await firstSlot.waitFor();
  const time = (await firstSlot.textContent()).trim();
  await firstSlot.click();
  await page.getByRole('button', { name: /Записаться/ }).click();
  assert.ok(await page.getByText('Введите имя').or(page.getByText('Enter your name')).isVisible(), 'client-side validation shown');
  const phone = `+90 555 ${Date.now().toString().slice(-7)}`;
  await page.getByLabel('Имя').fill('E2E Клиент');
  await page.getByLabel('Телефон').fill(phone);
  await page.getByRole('checkbox').check();
  await page.getByRole('button', { name: `Записаться на ${time}` }).click();
  await page.getByText(/Вы записаны|Заявка отправлена/).waitFor({ timeout: 10000 });
  console.log(`booked ${time}`);

  // owner sees it in the calendar
  const login = await fetch(`${API}/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: 'demo@beauty-crm.test', password: 'Demo12345!' }) }).then((r) => r.json());
  const me = await fetch(`${API}/auth/me`, { headers: { authorization: `Bearer ${login.accessToken}` } }).then((r) => r.json());
  const biz = me.memberships[0].business.id;
  const clients = await fetch(`${API}/businesses/${biz}/clients?q=${encodeURIComponent(phone.replace(/\D/g, '').slice(-7))}`, { headers: { authorization: `Bearer ${login.accessToken}` } }).then((r) => r.json());
  assert.equal(clients.total, 1, 'client created from online booking');
  const profile = await fetch(`${API}/businesses/${biz}/clients/${clients.items[0].id}`, { headers: { authorization: `Bearer ${login.accessToken}` } }).then((r) => r.json());
  assert.equal(profile.appointments.length, 1);
  assert.equal(profile.appointments[0].source, 'ONLINE');

  // second visitor no longer sees that slot on that day
  const p2 = await browser.newPage();
  await p2.goto(`${WEB}/${SLUG}`);
  await p2.getByRole('button', { name: /Маникюр с однотонным покрытием/ }).click();
  await p2.getByRole('group', { name: 'Время' }).getByRole('button').first().waitFor();
  const first2 = (await p2.getByRole('group', { name: 'Время' }).getByRole('button').first().textContent()).trim();
  assert.notEqual(first2, time, 'booked slot is no longer offered');
  console.log('E2E public booking: OK');
} finally {
  await browser.close();
}
