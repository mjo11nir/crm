import { NextRequest, NextResponse } from 'next/server';
import { API_URL } from '../../../../lib/api';
import { isValidSlug, validateBooking } from '../../../../lib/validation';

export async function POST(req: NextRequest, { params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const key = req.headers.get('idempotency-key') ?? '';
  if (!isValidSlug(slug) || !/^[A-Za-z0-9-]{16,64}$/.test(key)) return NextResponse.json({ message: 'Invalid request' }, { status: 400 });
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ message: 'Invalid JSON' }, { status: 400 });
  }
  const v = validateBooking(body);
  if (!v.ok) return NextResponse.json({ message: 'Validation failed', errors: v.errors }, { status: 400 });
  const r = await fetch(`${API_URL}/public/${slug}/bookings`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'idempotency-key': key, 'x-forwarded-for': req.headers.get('x-forwarded-for') ?? '' },
    body: JSON.stringify(v.value),
    cache: 'no-store',
  });
  return NextResponse.json(await r.json(), { status: r.status });
}
