# Known issues and limitations

Nothing in this list is presented as done in the app: blocked integrations show "not connected" in the UI or return an explicit error code.

## Blocked on external credentials / approvals
- **Payments & online deposits** — no payment provider integrated. Online bookings for services with a deposit are rejected (`DEPOSIT_PROVIDER_UNAVAILABLE`). Staff can record cash/card/transfer payments manually.
- **Push / email / SMS / WhatsApp** — jobs are queued, retried and logged, but delivered by a **sandbox adapter** that sends nothing.
- **WhatsApp / Instagram inboxes, calendar sync** — not connected.
- **App Store / Google Play billing** — subscriptions are enforced server-side but purchases cannot be made in-app; plans are set manually (`store = MANUAL`).
- **Password reset / phone verification** — require an email/SMS provider.

## Not implemented yet
admin-web; products & inventory; staff invitations (multi-employee UI); XLSX import/export; photo uploads (avatars, gallery, client photos); reviews; portfolio; reactivation campaigns; birthday reminders; waitlist offer expiry; offline write queue; WebSockets; performance test suite; UI for CSV import / duplicate merge / expenses.

## Environment limitations during development
- Android SDK and Docker daemon were unavailable in the build sandbox → APK, iOS build and `docker compose` were **not executed here**; they are covered by CI workflows that have not run yet.
- GitHub Actions workflows have not been executed.
- Mobile UI uses the bundled Inter font (a ~7% width compensation is applied) instead of SF Pro, so text metrics differ slightly from the screenshots.
- Times in the mobile app are shown in the business timezone; the booking site formats dates in the business timezone.
