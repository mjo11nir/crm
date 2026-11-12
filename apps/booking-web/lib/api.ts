// Server-only helpers: the browser never talks to the core API directly.
export const API_URL = process.env.API_INTERNAL_URL ?? 'http://localhost:3000/api/v1';

export interface PublicService { id: string; name: string; description: string | null; category: string | null; durationMinutes: number; priceMinor: number; depositMinor: number }
export interface PublicInfo {
  business: { name: string; slug: string; phone: string | null; description: string | null; themeColor: string; timezone: string; currency: string; maxHorizonDays: number; cancellationDeadlineMin: number; requireApproval: boolean };
  services: PublicService[];
  locations: { id: string; name: string; address: string | null }[];
  employees: { id: string; displayName: string }[];
  workingHours: { weekday: number; startMinute: number; endMinute: number }[];
}

export async function getPublicInfo(slug: string): Promise<PublicInfo | null> {
  const r = await fetch(`${API_URL}/public/${encodeURIComponent(slug)}`, { cache: 'no-store' });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`API error ${r.status}`);
  return r.json();
}
