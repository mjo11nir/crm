'use client';

import { useEffect, useMemo, useState } from 'react';
import type { PublicInfo } from '../../lib/api';
import { formatMoney, validateBooking } from '../../lib/validation';

interface Slot { start: string; localTime: string }
interface Day { date: string; slots: Slot[]; reason?: string }
interface Confirmation { bookingId: string; status: string; startsAt: string; services: string[]; priceMinor: number; currency: string }

function localDates(count: number, timeZone: string): string[] {
  const out: string[] = [];
  const fmt = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' });
  const now = Date.now();
  for (let i = 0; i < count; i++) out.push(fmt.format(new Date(now + i * 86_400_000)));
  return [...new Set(out)];
}

function newKey(): string {
  return crypto.randomUUID();
}

const ERRORS: Record<string, string> = {
  SLOT_TAKEN: 'Это время уже заняли. Пожалуйста, выберите другое.',
  DEPOSIT_PROVIDER_UNAVAILABLE: 'Для этой услуги нужна предоплата — онлайн-оплата пока недоступна. Свяжитесь с мастером.',
};

export default function BookingFlow({ slug, info }: { slug: string; info: PublicInfo }) {
  const { business, services } = info;
  const [serviceId, setServiceId] = useState<string | null>(null);
  const horizon = Math.min(business.maxHorizonDays, 30);
  const dates = useMemo(() => localDates(horizon, business.timezone), [horizon, business.timezone]);
  const [date, setDate] = useState(dates[0]);
  const [days, setDays] = useState<Record<string, Day>>({});
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [slot, setSlot] = useState<Slot | null>(null);
  const [form, setForm] = useState({ fullName: '', phone: '', email: '', comment: '', acceptPolicy: false });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [done, setDone] = useState<Confirmation | null>(null);
  // one idempotency key per booking attempt: retries of the same submission never double-book
  const [idemKey, setIdemKey] = useState(newKey);

  const service = services.find((s) => s.id === serviceId) ?? null;

  useEffect(() => {
    if (!serviceId) return;
    let cancelled = false;
    setLoading(true);
    setLoadError(null);
    setSlot(null);
    fetch(`/api/${slug}/availability?from=${dates[0]}&to=${dates[dates.length - 1]}&serviceIds=${serviceId}`)
      .then(async (r) => {
        if (!r.ok) throw new Error((await r.json()).message ?? 'Error');
        return r.json();
      })
      .then((data: { days: Day[] }) => {
        if (cancelled) return;
        setDays(Object.fromEntries(data.days.map((d) => [d.date, d])));
        const first = data.days.find((d) => d.slots.length > 0);
        if (first) setDate(first.date);
      })
      .catch((e: Error) => !cancelled && setLoadError(e.message))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [serviceId, slug, dates]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitError(null);
    const payload = {
      serviceIds: serviceId ? [serviceId] : [],
      startsAt: slot?.start ?? '',
      client: { fullName: form.fullName, phone: form.phone, email: form.email || undefined },
      comment: form.comment || undefined,
      acceptPolicy: form.acceptPolicy,
    };
    const v = validateBooking(payload);
    if (!v.ok) {
      setErrors(v.errors);
      return;
    }
    setErrors({});
    setSubmitting(true);
    try {
      const r = await fetch(`/api/${slug}/bookings`, { method: 'POST', headers: { 'content-type': 'application/json', 'idempotency-key': idemKey }, body: JSON.stringify(v.value) });
      const body = await r.json();
      if (!r.ok) {
        const msg = Array.isArray(body.message) ? body.message.join(', ') : body.message;
        setSubmitError(ERRORS[body.code] ?? msg ?? 'Не удалось записаться');
        if (body.code === 'SLOT_TAKEN') {
          setSlot(null);
          setIdemKey(newKey());
          setDays((d) => ({ ...d, [date]: { ...d[date], slots: d[date].slots.filter((s) => s.start !== payload.startsAt) } }));
        }
        return;
      }
      setDone(body);
    } catch {
      setSubmitError('Нет соединения. Попробуйте ещё раз — повторная отправка не создаст двойную запись.');
    } finally {
      setSubmitting(false);
    }
  }

  if (done) {
    const when = new Intl.DateTimeFormat('ru-RU', { timeZone: business.timezone, weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }).format(new Date(done.startsAt));
    return (
      <section className="card success" aria-live="polite">
        <div className="big" aria-hidden>✓</div>
        <h1>{done.status === 'PENDING_APPROVAL' ? 'Заявка отправлена' : 'Вы записаны!'}</h1>
        <p>{when}</p>
        <p className="muted">
          {done.services.join(', ')} · {formatMoney(done.priceMinor, done.currency)}
        </p>
        {done.status === 'PENDING_APPROVAL' && <p className="muted">Мастер подтвердит запись в ближайшее время.</p>}
      </section>
    );
  }

  const day = days[date];
  const dayLabel = (d: string) => {
    const dt = new Date(`${d}T12:00:00Z`);
    return { wd: new Intl.DateTimeFormat('ru-RU', { weekday: 'short', timeZone: 'UTC' }).format(dt), n: dt.getUTCDate() };
  };

  return (
    <>
      <h2>1. Услуга</h2>
      <div className="card" role="group" aria-label="Услуги">
        {services.length === 0 && <p className="muted">Онлайн-запись на услуги пока недоступна.</p>}
        {services.map((s) => (
          <button key={s.id} type="button" className="option" aria-pressed={s.id === serviceId} onClick={() => setServiceId(s.id)}>
            <div className="row">
              <span>
                {s.name}
                <br />
                <small className="muted">{s.durationMinutes} мин</small>
              </span>
              <span>{formatMoney(s.priceMinor, business.currency)}</span>
            </div>
          </button>
        ))}
      </div>

      {service && (
        <>
          <h2>2. Дата и время</h2>
          <div className="card">
            <div className="days" role="group" aria-label="Даты">
              {dates.map((d) => {
                const l = dayLabel(d);
                const has = (days[d]?.slots.length ?? 0) > 0;
                return (
                  <button key={d} type="button" className="day" aria-pressed={d === date} disabled={loading || !has} onClick={() => (setDate(d), setSlot(null))} aria-label={d}>
                    <div className="muted" style={{ fontSize: 12 }}>{l.wd}</div>
                    <div style={{ fontSize: 20 }}>{l.n}</div>
                  </button>
                );
              })}
            </div>
            <div style={{ marginTop: 12 }}>
              {loading && <div className="skeleton" aria-label="Загрузка" />}
              {loadError && <p className="error">{loadError}</p>}
              {!loading && !loadError && day && day.slots.length === 0 && <p className="muted">Нет свободного времени в этот день</p>}
              {!loading && day && day.slots.length > 0 && (
                <div className="chips" role="group" aria-label="Время">
                  {day.slots.map((s) => (
                    <button key={s.start} type="button" className="chip" aria-pressed={slot?.start === s.start} onClick={() => setSlot(s)}>
                      {s.localTime}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}

      {slot && (
        <form onSubmit={submit} noValidate>
          <h2>3. Контакты</h2>
          <div className="card">
            <label htmlFor="fullName">Имя</label>
            <input id="fullName" autoComplete="name" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} aria-invalid={!!errors.fullName} />
            {errors.fullName && <div className="error">{errors.fullName}</div>}
            <label htmlFor="phone">Телефон</label>
            <input id="phone" type="tel" autoComplete="tel" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} aria-invalid={!!errors.phone} />
            {errors.phone && <div className="error">{errors.phone}</div>}
            <label htmlFor="email">Email (необязательно)</label>
            <input id="email" type="email" autoComplete="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            {errors.email && <div className="error">{errors.email}</div>}
            <label htmlFor="comment">Комментарий</label>
            <textarea id="comment" rows={2} value={form.comment} onChange={(e) => setForm({ ...form, comment: e.target.value })} />
            <label className="check">
              <input type="checkbox" checked={form.acceptPolicy} onChange={(e) => setForm({ ...form, acceptPolicy: e.target.checked })} />
              <span>
                Я согласен(на) с правилами записи и обработкой персональных данных. Отмена — не позднее чем за {Math.round(business.cancellationDeadlineMin / 60)} ч.
              </span>
            </label>
            {errors.acceptPolicy && <div className="error">{errors.acceptPolicy}</div>}
            {submitError && (
              <p className="error" role="alert">
                {submitError}
              </p>
            )}
            <button className="primary" type="submit" disabled={submitting}>
              {submitting ? 'Записываем…' : `Записаться на ${slot.localTime}`}
            </button>
          </div>
        </form>
      )}
    </>
  );
}
