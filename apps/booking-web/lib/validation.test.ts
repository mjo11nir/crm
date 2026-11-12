import assert from 'node:assert/strict';
import { test } from 'node:test';
import { formatMoney, isValidSlug, validateBooking } from './validation.ts';

const ok = {
  serviceIds: ['3f1d8a64-0d7b-4b7a-9a59-0b1e1b0b8c11'],
  startsAt: '2026-11-20T06:00:00.000Z',
  client: { fullName: 'Анна', phone: '+90 533 000 00 00' },
  acceptPolicy: true,
};

test('accepts a valid booking and normalises it', () => {
  const r = validateBooking({ ...ok, client: { ...ok.client, fullName: '  Анна  ' } });
  assert.equal(r.ok, true);
  if (r.ok) assert.equal(r.value.client.fullName, 'Анна');
});

test('rejects missing policy, bad phone, bad ids, bad email', () => {
  const r = validateBooking({ ...ok, acceptPolicy: false, serviceIds: ['x'], client: { fullName: 'A', phone: 'abc', email: 'nope' } });
  assert.equal(r.ok, false);
  if (!r.ok) assert.deepEqual(Object.keys(r.errors).sort(), ['acceptPolicy', 'email', 'fullName', 'phone', 'serviceIds']);
});

test('slug and money helpers', () => {
  assert.equal(isValidSlug('lavanda-studio'), true);
  assert.equal(isValidSlug('../etc/passwd'), false);
  assert.match(formatMoney(4500, 'EUR'), /45/);
});
