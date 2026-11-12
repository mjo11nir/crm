# Requirements traceability / implementation checklist

Legend: ✅ done & tested · 🟡 partial · ⛔ blocked (external dependency) · ❌ not started

| § | Requirement | Status | Where / evidence |
|---|---|---|---|
| 6 | Email registration/login, refresh rotation, logout all, delete account | ✅ | `auth/*`, integration tests "auth" |
| 6 | Password reset, phone verification | ⛔ | need email/SMS provider |
| 6 | Profile photo, multiple locations | 🟡 | locations ✅; photo upload ❌ (no file storage yet) |
| 6 | Roles + tenant isolation | ✅ | `common/auth.ts`, tests "tenant isolation" (Client role = public booking, no login) |
| 7 | Dashboard from live data | ✅ | `dashboard.controller.ts`, golden `home.png`, test |
| 8 | Day / Week / Feed views | ✅ | `schedule_screen.dart` |
| 8 | Create, edit, reschedule, cancel, complete, no-show, multiple services, custom duration, notes, discount, recurring | ✅ | `appointments.service.ts`, tests |
| 8 | Deposits / final payment | ✅ | `finance.service.ts`, test "payments & finance" |
| 8 | Assign staff | 🟡 | API supports `employeeId`; UI uses single specialist; inviting staff ❌ |
| 8 | Server-side conflict detection under concurrency | ✅ | exclusion constraint + advisory lock, 10/8-way concurrency tests |
| 9 | Client CRUD, search, tags, archive, history, spending, last/next visit, notes, discount, consent | ✅ | `clients.service.ts`, tests |
| 9 | CSV import/export, duplicates, merge | ✅ | API + tests (no UI for import/merge yet 🟡) |
| 9 | XLSX, client photos, birthday reminders, inactive detection | ❌ | |
| 10 | Services (duration, buffer, price, deposit, online flag, active) | ✅ | `catalog.controller.ts` |
| 10 | Products & inventory | ❌ | |
| 11 | Public booking page: info, services, dates, real slots, contacts, policy, confirmation | ✅ | `apps/booking-web`, E2E |
| 11 | Rules: min notice, horizon, slot step, approval, breaks, days off, buffers | ✅ | engine + settings |
| 11 | Atomic + idempotent booking | ✅ | tests |
| 11 | Deposit payment online | ⛔ | rejected with `DEPOSIT_PROVIDER_UNAVAILABLE` until a provider is integrated |
| 12 | Central availability engine incl. DST, overnight, reasons | ✅ | `engine.ts`, 15 unit tests |
| 13 | Free-slot sharing (PNG, share sheet, theme, period, location) | ✅ | `free_slots_screen.dart`, golden |
| 14 | Waitlist with single-offer guarantee | ✅ (offer expiry ❌) | `waitlist.service.ts`, test |
| 15 | Payment provider + webhooks, refunds | 🟡 | manual cash/card/transfer + refunds ✅; provider ⛔ |
| 16–17 | Finance reports, statistics | ✅ (charts basic, expenses UI ❌) | `finance/report`, `StatisticsScreen` |
| 18 | Notification queue, dedupe, retries, dead letter | ✅ | outbox + test |
| 18 | Real push/email/SMS/WhatsApp delivery | ⛔ | sandbox adapter only |
| 19 | Reactivation reminders | ❌ | |
| 20–21 | Professional web page (name/description ✅), portfolio, reviews | 🟡/❌ | |
| 22 | Internal chat + support tickets, unread | ✅ | `chats` |
| 22 | WhatsApp/Instagram inbox | ⛔ | Meta API approval needed (clearly labelled in UI) |
| 23 | Settings screens, 5 languages, dark theme | ✅ | `settings_screens.dart`, l10n tests |
| 23 | Calendar sync | ⛔ | |
| 24 | Trial/Premium/VIP entitlements enforced server-side | ✅ | `entitlements.ts`, tests |
| 24 | StoreKit / Play Billing purchase + verification | ⛔ | store accounts required |
| 25 | Normalized schema, UUIDs, FKs, indexes, migrations, ER diagram | ✅ (subset of listed tables) | `prisma/` |
| 26 | Offline read cache / offline edit queue | ✅ / ❌ | |
| 27 | Hashing, rotation, RBAC, validation, rate limits, audit log, secret & dependency scanning | ✅ | see `security.md` |
| 28 | Unit / integration / E2E / widget / golden / a11y / l10n tests | ✅ | 87 automated tests |
| 28 | Performance tests | ❌ | |
| 29 | GitHub Actions per area | ✅ written, not yet executed on GitHub | `.github/workflows` |
| 32 | Android APK / iOS build | ⛔ here | Android SDK download blocked in this sandbox; CI job builds it |
| 32 | admin-web | ❌ | |
