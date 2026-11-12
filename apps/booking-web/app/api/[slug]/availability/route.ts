import { NextRequest, NextResponse } from 'next/server';
import { API_URL } from '../../../../lib/api';
import { isValidSlug } from '../../../../lib/validation';

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const IDS = /^[0-9a-f-]{36}(,[0-9a-f-]{36}){0,4}$/i;

export async function GET(req: NextRequest, { params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const q = req.nextUrl.searchParams;
  const from = q.get('from') ?? '', to = q.get('to') ?? '', serviceIds = q.get('serviceIds') ?? '';
  if (!isValidSlug(slug) || !DATE.test(from) || !DATE.test(to) || !IDS.test(serviceIds)) {
    return NextResponse.json({ message: 'Invalid request' }, { status: 400 });
  }
  const url = new URL(`${API_URL}/public/${slug}/availability`);
  url.search = new URLSearchParams({ from, to, serviceIds }).toString();
  const r = await fetch(url, { cache: 'no-store' });
  return NextResponse.json(await r.json(), { status: r.status });
}
