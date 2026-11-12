# Security checklist & threat model

| Area | Threat | Control | Status |
|---|---|---|---|
| Auth | credential stuffing | bcrypt (12 rounds), constant-ish timing on unknown users, login rate limit 10/min | ✅ |
| Auth | stolen refresh token | hashed at rest, rotation, reuse detection revokes family, logout-all | ✅ tested |
| Auth | token confusion | JWT `typ=access`, HS256 pinned, secret ≥ 32 chars required at boot | ✅ |
| Tenancy | cross-tenant access (IDOR) | membership check per `:businessId` + `businessId` in every query | ✅ tested |
| RBAC | employee changing settings/finance | `@Roles` | ✅ tested |
| Booking | double booking / race | engine check + advisory lock + DB exclusion constraint | ✅ tested |
| Booking | replay / duplicate submit | Idempotency-Key with request hash | ✅ tested |
| Booking | abuse / spam | per-route throttling on public endpoints; slug & body validated in Next and API | ✅ (CAPTCHA ❌) |
| Input | mass assignment / injection | `ValidationPipe` whitelist + forbidNonWhitelisted; Prisma parameterised queries; tagged `$queryRaw` | ✅ |
| Export | CSV formula injection | cells starting with `= + - @` are prefixed | ✅ tested |
| Payments | forged success | no client-side success; only manual staff payments; provider webhooks must verify signatures (future) | ⛔ provider |
| Uploads | malicious files | no upload endpoints yet | n/a |
| Secrets | leaked keys | `.env` ignored, `.env.example` placeholders, gitleaks in CI | ✅ |
| Dependencies | vulnerable packages | `pnpm audit` in CI; overrides for postcss/sharp/deepmerge-ts; Next 15.5.29 | ✅ 0 known high/critical at time of writing |
| Mobile | token theft on device | Keychain/Keystore via flutter_secure_storage | ✅ |
| Web | clickjacking/sniffing | X-Frame-Options DENY, nosniff, Referrer-Policy; `x-powered-by` disabled | ✅ |
| Audit | repudiation | `audit_logs` for business/schedule/appointment changes | ✅ |
| Privacy | right to erasure / export | account deletion cascades tenant data; client CSV export | ✅ (per-client erase endpoint ❌) |
| Ops | TLS, encrypted backups | must be provided by hosting (see deployment.md) | ⛔ infra |
