import { notFound } from 'next/navigation';
import { getPublicInfo } from '../../lib/api';
import { isValidSlug } from '../../lib/validation';
import BookingFlow from './BookingFlow';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const info = isValidSlug(slug) ? await getPublicInfo(slug).catch(() => null) : null;
  return { title: info ? `${info.business.name} — online booking` : 'Online booking' };
}

export default async function BusinessPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  if (!isValidSlug(slug)) notFound();
  const info = await getPublicInfo(slug);
  if (!info) notFound();
  const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const hm = (m: number) => `${String(Math.floor(m / 60) % 24).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  return (
    <main style={{ ['--theme' as string]: info.business.themeColor }}>
      <header className="header">
        <div className="avatar" aria-hidden>✦</div>
        <div>
          <h1>{info.business.name}</h1>
          {info.business.phone && <div style={{ opacity: 0.85 }}>{info.business.phone}</div>}
          {info.locations[0] && (
            <div style={{ opacity: 0.75 }}>
              {info.locations[0].name}
              {info.locations[0].address ? `, ${info.locations[0].address}` : ''}
            </div>
          )}
        </div>
      </header>
      {info.business.description && <p className="card">{info.business.description}</p>}
      {info.workingHours.length > 0 && (
        <details className="card">
          <summary>Часы работы</summary>
          {info.workingHours.map((w, i) => (
            <div className="row" key={i}>
              <span>{days[w.weekday]}</span>
              <span className="muted">
                {hm(w.startMinute)} – {hm(w.endMinute)}
              </span>
            </div>
          ))}
        </details>
      )}
      <BookingFlow slug={slug} info={info} />
    </main>
  );
}
