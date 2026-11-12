# Database

The canonical PostgreSQL schema and migrations live with the API so Prisma can generate the typed client:

- Schema: [`services/api/prisma/schema.prisma`](../services/api/prisma/schema.prisma)
- Migrations: [`services/api/prisma/migrations`](../services/api/prisma/migrations)
- Seed (demo data, dev only): [`services/api/src/seed.ts`](../services/api/src/seed.ts)
- ER diagram: [`docs/er-diagram.md`](../docs/er-diagram.md)

Hand-written SQL constraints (in the init migration):

| Constraint | Purpose |
|---|---|
| `appointments_no_overlap` (GiST exclusion, `btree_gist`) | One employee can never hold two overlapping active appointments — the final guard against double booking under concurrency |
| `appointments_valid_interval` | `endsAt > startsAt` |
| `services_*` checks | positive duration, non-negative price, deposit ≤ price |
| `payments_amount_positive` | amounts stored as positive minor units |
| `work_schedules_valid` | ISO weekday 1–7, minute ranges valid (overnight up to 48h) |
