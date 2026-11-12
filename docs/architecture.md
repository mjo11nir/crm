# Architecture

```
 Flutter app (iOS/Android/web) ──HTTPS/JSON──┐
                                             ├──► NestJS API ──► PostgreSQL 16
 Browser ──► Next.js booking-web (route handlers, server-side validation) ──┘      (Redis reserved for queues/rate limits)
```

## Key decisions

| Topic | Decision |
|---|---|
| Tenancy | Every tenant-owned row has `businessId`. All tenant routes are `/businesses/:businessId/...`; a global guard verifies membership and role for that id before any handler runs, and every query additionally filters by `businessId` (a foreign id returns 404, never data). |
| Auth | Email + bcrypt; 15-min HS256 access JWT; opaque refresh tokens stored as SHA-256, rotated on every use, replay of a rotated token revokes the whole family; logout / logout-all / account deletion. |
| Time | UTC `timestamptz` in DB; business IANA timezone for all local logic. The **only** slot calculation is `services/api/src/availability/engine.ts` (pure, unit-tested incl. DST spring/fall and overnight shifts). Mobile displays times in the business zone via the `timezone` package. |
| Double booking | (1) slot re-validated by the engine inside the transaction, (2) per-employee `pg_advisory_xact_lock` serialises writers, (3) GiST exclusion constraint `appointments_no_overlap` is the final guarantee. Losers get `409 SLOT_TAKEN`. Tested with 10 concurrent staff and 8 concurrent public requests. |
| Idempotency | Public booking requires `Idempotency-Key`; key + request hash stored in `idempotency_keys`; replay returns the stored response, a different body is `409`. |
| Concurrency of edits | `appointments.version` optimistic lock → `409 VERSION_CONFLICT`. |
| Money | Integer minor units + ISO currency. Earned revenue comes from completed appointments; cash flow from payments — never double counted. |
| Subscriptions | Server-side `EntitlementGuard` (`@RequiresFeature`), `402 SUBSCRIPTION_REQUIRED`. Reads stay available after expiry (data access); writes and online booking stop. |
| Notifications | Transactional outbox table `notification_jobs` with unique `dedupeKey`, `FOR UPDATE SKIP LOCKED` worker, exponential backoff, dead-letter after 5 attempts. Delivery adapter is a **sandbox** (no real messages). |
| Offline | Mobile caches read responses (dashboard, day, clients, services, business) and falls back on network errors. Writes are online-only and never shown as confirmed before the server accepts them. |

## Deviations from the requested stack (and why)

| Requested | Used | Reason |
|---|---|---|
| Drift/SQLite offline store | `shared_preferences` JSON cache | Read-only cache was enough for the slice; no offline write queue yet (see limitations). |
| Freezed/json_serializable | hand-written models | Avoids build_runner step; models are small. |
| BullMQ/Redis | PostgreSQL outbox + poller | Transactional enqueue with the booking itself; Redis is in compose for a later BullMQ switch. |
| WebSockets | pull-to-refresh + provider invalidation | Not needed for single-user flows yet. |
| admin-web | not built | Business admin is done in the mobile app. |
| Prisma schema in `database/` | `services/api/prisma` | Prisma client generation requires the schema next to the package; `database/README.md` points there. |
