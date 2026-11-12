# Beauty CRM

CRM и онлайн-запись для бьюти-мастеров: мобильное приложение (Flutter, Android/iOS), публичная страница онлайн-записи (Next.js), API (NestJS + PostgreSQL).
Собственная реализация — свой код, брендинг, иконки и шрифт (Inter, OFL). Дизайн повторяет структуру и паттерны со скриншотов в [`docs/reference`](docs/reference).

> Статус: рабочий вертикальный срез (auth → клиенты → услуги → записи → календарь → онлайн-запись → оплаты → статистика) с реальным хранением в PostgreSQL и автотестами.
> Что **не** сделано или заблокировано — честно перечислено в [`docs/known-limitations.md`](docs/known-limitations.md).

## Структура

```
apps/mobile        Flutter-приложение (Riverpod, GoRouter, Dio), ru/en/tr/pt/es, светлая/тёмная тема
apps/booking-web   Публичная онлайн-запись (Next.js 15, server-side validation, идемпотентная запись)
services/api       NestJS + Prisma + PostgreSQL. Схема и миграции: services/api/prisma
packages/design-tokens  Цвета/радиусы/шрифты
tests/e2e          Playwright E2E (браузер → booking-web → API → PostgreSQL)
infrastructure     Dockerfile'ы
docs               Архитектура, аудит референсов, матрица требований, безопасность, деплой, OpenAPI
```

## Быстрый старт (локально)

Требования: Node 22 + pnpm 10, PostgreSQL 16, Flutter 3.50.

```bash
pnpm install
```

```bash
cp .env.example .env
```

```bash
cd services/api && npx prisma migrate deploy && pnpm seed && pnpm dev
```

```bash
cd apps/booking-web && pnpm dev
```

```bash
cd apps/mobile && flutter run --dart-define=API_URL=http://localhost:3000/api/v1
```

Демо-вход (создаётся `pnpm seed`, только для разработки): `demo@beauty-crm.test` / `Demo12345!`
Страница записи демо-студии: http://localhost:3001/lavanda-studio — API docs (Swagger): http://localhost:3000/api/docs

Либо всё в Docker: `docker compose up --build` (см. `docker-compose.yml`).

## Тесты

| Набор | Команда | Результат на момент сдачи |
|---|---|---|
| API unit (движок доступности, деньги, подписки, CSV) | `cd services/api && pnpm test:unit` | 22 passed |
| API integration (реальный PostgreSQL: auth, изоляция тенантов, CRUD, конкурентная запись, идемпотентность, платежи, уведомления, лист ожидания, подписки) | `cd services/api && pnpm test:integration` | 21 passed |
| Mobile widget + golden (5 эталонных экранов, тёмная тема, 5 языков, маленький/большой экран, a11y) | `cd apps/mobile && flutter test` | 18 passed |
| Booking-web unit | `cd apps/booking-web && pnpm test` | 3 passed |
| E2E онлайн-записи | `cd tests && pnpm e2e` (нужны запущенные API и web) | passed |

CI: `.github/workflows/` — api, booking-web, mobile (тесты + Android APK + iOS no-codesign), e2e, security (gitleaks, pnpm audit, CodeQL).

## Документация

- [Архитектура](docs/architecture.md) · [ER-диаграмма](docs/er-diagram.md) · [OpenAPI](docs/openapi.json)
- [Аудит референсных скриншотов](docs/reference-audit.md) · [Матрица требований / чеклист](docs/traceability.md)
- [Безопасность и модель угроз](docs/security.md) · [Деплой и откат](docs/deployment.md)
- [Известные ограничения](docs/known-limitations.md)
