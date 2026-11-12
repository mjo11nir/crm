# ER diagram

```mermaid
erDiagram
  users ||--o{ business_members : has
  users ||--o{ refresh_tokens : has
  businesses ||--o{ business_members : has
  businesses ||--|| subscriptions : has
  businesses ||--o{ work_locations : has
  businesses ||--o{ employees : has
  business_members ||--o| employees : is
  employees ||--o{ work_schedules : has
  work_locations ||--o{ work_schedules : at
  employees ||--o{ schedule_exceptions : has
  businesses ||--o{ service_categories : has
  service_categories ||--o{ services : groups
  businesses ||--o{ clients : has
  businesses ||--o{ appointments : has
  clients ||--o{ appointments : books
  employees ||--o{ appointments : performs
  work_locations ||--o{ appointments : at
  appointments ||--o{ appointment_services : contains
  services ||--o{ appointment_services : referenced
  appointments ||--o{ appointment_status_history : logs
  appointments ||--o{ payments : paid_by
  clients ||--o{ payments : pays
  businesses ||--o{ expenses : has
  clients ||--o{ waitlist_entries : waits
  services ||--o{ waitlist_entries : for
  businesses ||--o{ conversations : has
  conversations ||--o{ messages : has
  businesses ||--o{ notification_jobs : queues
  businesses ||--o{ idempotency_keys : stores
  businesses ||--o{ audit_logs : logs
```

Constraints beyond FKs: see `database/README.md` (exclusion constraint, checks). All PKs are UUID; deletes cascade from `businesses` (tenant erase), appointments keep `Restrict` on employee/location/service so history cannot be orphaned.
