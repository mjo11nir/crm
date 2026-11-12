# Deployment

## Environments
`staging` and `production` each need: PostgreSQL 16 (managed, encrypted at rest, daily backups + PITR), the API container, the booking-web container, TLS-terminating load balancer. Configuration via environment variables only (`.env.example`).

## Release
1. CI green on the PR (api, booking-web, mobile, e2e, security).
2. Build images from `infrastructure/docker/*.Dockerfile`, tag with the git SHA.
3. Run migrations as a one-off release job: `npx prisma migrate deploy` (migrations are forward-only and additive).
4. Deploy API, then booking-web; health check `GET /api/v1/health`.
5. Mobile: `flutter build appbundle` / `flutter build ipa` with `--dart-define=API_URL=...`; iOS signing needs Apple certificate + provisioning profile as CI secrets.

## Rollback
- Containers: redeploy the previous SHA tag.
- Database: migrations are designed to be backward compatible with the previous app version; if a migration must be reverted, restore from PITR to a new instance and repoint (never drop tables in-place).

## Not verified in this repository's build environment
Docker builds and the CI workflows were written but not executed (no Docker daemon / no GitHub runner in the sandbox).
