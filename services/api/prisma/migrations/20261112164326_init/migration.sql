-- CreateEnum
CREATE TYPE "MemberRole" AS ENUM ('OWNER', 'ADMIN', 'EMPLOYEE');

-- CreateEnum
CREATE TYPE "AppointmentStatus" AS ENUM ('BOOKED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "AppointmentSource" AS ENUM ('STAFF', 'ONLINE');

-- CreateEnum
CREATE TYPE "PaymentKind" AS ENUM ('DEPOSIT', 'PAYMENT', 'REFUND');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CASH', 'CARD', 'TRANSFER', 'ONLINE');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "SubscriptionTier" AS ENUM ('TRIAL', 'PREMIUM', 'VIP');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'GRACE', 'EXPIRED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "WaitlistStatus" AS ENUM ('WAITING', 'OFFERED', 'BOOKED', 'REMOVED');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('PUSH', 'EMAIL', 'SMS', 'WHATSAPP');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('QUEUED', 'SENT', 'FAILED');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT,
    "avatarUrl" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'ru',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "deletedAt" TIMESTAMPTZ(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "familyId" UUID NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "replacedBy" UUID,
    "userAgent" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "businesses" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'Europe/Istanbul',
    "currency" CHAR(3) NOT NULL DEFAULT 'EUR',
    "phone" TEXT,
    "description" TEXT,
    "avatarUrl" TEXT,
    "themeColor" TEXT NOT NULL DEFAULT '#9137E8',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    "onlineBookingEnabled" BOOLEAN NOT NULL DEFAULT true,
    "minNoticeMinutes" INTEGER NOT NULL DEFAULT 60,
    "maxHorizonDays" INTEGER NOT NULL DEFAULT 60,
    "slotStepMinutes" INTEGER NOT NULL DEFAULT 15,
    "cancellationDeadlineMin" INTEGER NOT NULL DEFAULT 1440,
    "requireApproval" BOOLEAN NOT NULL DEFAULT false,
    "waitlistEnabled" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "businesses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "business_members" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "MemberRole" NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "business_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_locations" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employees" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "memberId" UUID,
    "displayName" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_schedules" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "employeeId" UUID NOT NULL,
    "locationId" UUID NOT NULL,
    "weekday" SMALLINT NOT NULL,
    "startMinute" INTEGER NOT NULL,
    "endMinute" INTEGER NOT NULL,
    "breakStartMinute" INTEGER,
    "breakEndMinute" INTEGER,

    CONSTRAINT "work_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "schedule_exceptions" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "employeeId" UUID NOT NULL,
    "date" DATE NOT NULL,
    "isClosed" BOOLEAN NOT NULL DEFAULT true,
    "startMinute" INTEGER,
    "endMinute" INTEGER,
    "note" TEXT,

    CONSTRAINT "schedule_exceptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "service_categories" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "service_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "services" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "categoryId" UUID,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "durationMinutes" INTEGER NOT NULL,
    "bufferMinutes" INTEGER NOT NULL DEFAULT 0,
    "priceMinor" INTEGER NOT NULL,
    "depositMinor" INTEGER NOT NULL DEFAULT 0,
    "onlineBookable" BOOLEAN NOT NULL DEFAULT true,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clients" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT,
    "phoneNormalized" TEXT,
    "email" TEXT,
    "birthday" DATE,
    "notes" TEXT,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "discountPercent" INTEGER NOT NULL DEFAULT 0,
    "marketingConsent" BOOLEAN NOT NULL DEFAULT false,
    "archivedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointments" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "clientId" UUID,
    "employeeId" UUID NOT NULL,
    "locationId" UUID NOT NULL,
    "startsAt" TIMESTAMPTZ(3) NOT NULL,
    "endsAt" TIMESTAMPTZ(3) NOT NULL,
    "status" "AppointmentStatus" NOT NULL DEFAULT 'BOOKED',
    "source" "AppointmentSource" NOT NULL DEFAULT 'STAFF',
    "priceMinor" INTEGER NOT NULL,
    "discountMinor" INTEGER NOT NULL DEFAULT 0,
    "notes" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "appointments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointment_services" (
    "id" UUID NOT NULL,
    "appointmentId" UUID NOT NULL,
    "serviceId" UUID NOT NULL,
    "nameSnapshot" TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "priceMinor" INTEGER NOT NULL,

    CONSTRAINT "appointment_services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointment_status_history" (
    "id" UUID NOT NULL,
    "appointmentId" UUID NOT NULL,
    "fromStatus" "AppointmentStatus",
    "toStatus" "AppointmentStatus" NOT NULL,
    "changedBy" UUID,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "appointment_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "appointmentId" UUID,
    "clientId" UUID,
    "kind" "PaymentKind" NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'SUCCEEDED',
    "amountMinor" INTEGER NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "providerRef" TEXT,
    "paidAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "category" TEXT NOT NULL,
    "amountMinor" INTEGER NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "note" TEXT,
    "spentAt" TIMESTAMPTZ(3) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "waitlist_entries" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "serviceId" UUID NOT NULL,
    "preferredFrom" DATE NOT NULL,
    "preferredTo" DATE NOT NULL,
    "fromMinute" INTEGER NOT NULL DEFAULT 0,
    "toMinute" INTEGER NOT NULL DEFAULT 1440,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "status" "WaitlistStatus" NOT NULL DEFAULT 'WAITING',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "waitlist_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conversations" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'INTERNAL',
    "title" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "messages" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "senderUserId" UUID,
    "body" TEXT NOT NULL,
    "readAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "tier" "SubscriptionTier" NOT NULL,
    "status" "SubscriptionStatus" NOT NULL,
    "startedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "store" TEXT,
    "storeRef" TEXT,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_jobs" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "recipient" TEXT NOT NULL,
    "template" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "NotificationStatus" NOT NULL DEFAULT 'QUEUED',
    "dedupeKey" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "scheduledFor" TIMESTAMPTZ(3) NOT NULL,
    "sentAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_jobs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_keys" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "scope" TEXT NOT NULL,
    "requestHash" TEXT NOT NULL,
    "responseBody" JSONB,
    "statusCode" INTEGER,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "businessId" UUID NOT NULL,
    "userId" UUID,
    "action" TEXT NOT NULL,
    "entity" TEXT NOT NULL,
    "entityId" TEXT,
    "data" JSONB,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "refresh_tokens_userId_idx" ON "refresh_tokens"("userId");

-- CreateIndex
CREATE INDEX "refresh_tokens_familyId_idx" ON "refresh_tokens"("familyId");

-- CreateIndex
CREATE UNIQUE INDEX "businesses_slug_key" ON "businesses"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "business_members_businessId_userId_key" ON "business_members"("businessId", "userId");

-- CreateIndex
CREATE INDEX "work_locations_businessId_idx" ON "work_locations"("businessId");

-- CreateIndex
CREATE UNIQUE INDEX "employees_memberId_key" ON "employees"("memberId");

-- CreateIndex
CREATE INDEX "employees_businessId_idx" ON "employees"("businessId");

-- CreateIndex
CREATE INDEX "work_schedules_businessId_employeeId_idx" ON "work_schedules"("businessId", "employeeId");

-- CreateIndex
CREATE UNIQUE INDEX "schedule_exceptions_employeeId_date_key" ON "schedule_exceptions"("employeeId", "date");

-- CreateIndex
CREATE INDEX "service_categories_businessId_idx" ON "service_categories"("businessId");

-- CreateIndex
CREATE INDEX "services_businessId_idx" ON "services"("businessId");

-- CreateIndex
CREATE INDEX "clients_businessId_fullName_idx" ON "clients"("businessId", "fullName");

-- CreateIndex
CREATE INDEX "clients_businessId_phoneNormalized_idx" ON "clients"("businessId", "phoneNormalized");

-- CreateIndex
CREATE INDEX "appointments_businessId_startsAt_idx" ON "appointments"("businessId", "startsAt");

-- CreateIndex
CREATE INDEX "appointments_employeeId_startsAt_idx" ON "appointments"("employeeId", "startsAt");

-- CreateIndex
CREATE INDEX "appointment_services_appointmentId_idx" ON "appointment_services"("appointmentId");

-- CreateIndex
CREATE INDEX "appointment_status_history_appointmentId_idx" ON "appointment_status_history"("appointmentId");

-- CreateIndex
CREATE UNIQUE INDEX "payments_providerRef_key" ON "payments"("providerRef");

-- CreateIndex
CREATE INDEX "payments_businessId_paidAt_idx" ON "payments"("businessId", "paidAt");

-- CreateIndex
CREATE INDEX "expenses_businessId_spentAt_idx" ON "expenses"("businessId", "spentAt");

-- CreateIndex
CREATE INDEX "waitlist_entries_businessId_status_idx" ON "waitlist_entries"("businessId", "status");

-- CreateIndex
CREATE INDEX "conversations_businessId_idx" ON "conversations"("businessId");

-- CreateIndex
CREATE INDEX "messages_conversationId_createdAt_idx" ON "messages"("conversationId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_businessId_key" ON "subscriptions"("businessId");

-- CreateIndex
CREATE UNIQUE INDEX "notification_jobs_dedupeKey_key" ON "notification_jobs"("dedupeKey");

-- CreateIndex
CREATE INDEX "notification_jobs_status_scheduledFor_idx" ON "notification_jobs"("status", "scheduledFor");

-- CreateIndex
CREATE UNIQUE INDEX "idempotency_keys_businessId_scope_key_key" ON "idempotency_keys"("businessId", "scope", "key");

-- CreateIndex
CREATE INDEX "audit_logs_businessId_createdAt_idx" ON "audit_logs"("businessId", "createdAt");

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "business_members" ADD CONSTRAINT "business_members_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "business_members" ADD CONSTRAINT "business_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_locations" ADD CONSTRAINT "work_locations_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employees" ADD CONSTRAINT "employees_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employees" ADD CONSTRAINT "employees_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "business_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_schedules" ADD CONSTRAINT "work_schedules_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_schedules" ADD CONSTRAINT "work_schedules_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_schedules" ADD CONSTRAINT "work_schedules_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "work_locations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "schedule_exceptions" ADD CONSTRAINT "schedule_exceptions_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "schedule_exceptions" ADD CONSTRAINT "schedule_exceptions_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_categories" ADD CONSTRAINT "service_categories_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "services" ADD CONSTRAINT "services_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "services" ADD CONSTRAINT "services_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "service_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "clients" ADD CONSTRAINT "clients_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "work_locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointment_services" ADD CONSTRAINT "appointment_services_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "appointments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointment_services" ADD CONSTRAINT "appointment_services_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "services"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointment_status_history" ADD CONSTRAINT "appointment_status_history_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "appointments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_jobs" ADD CONSTRAINT "notification_jobs_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------
-- Hand-written constraints (not expressible in Prisma schema)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- An employee can never hold two active appointments whose intervals overlap.
-- This is the final guard against double booking under concurrency.
ALTER TABLE "appointments"
  ADD CONSTRAINT "appointments_no_overlap"
  EXCLUDE USING gist (
    "employeeId" WITH =,
    tstzrange("startsAt", "endsAt", '[)') WITH &&
  ) WHERE ("status" IN ('BOOKED', 'CONFIRMED', 'COMPLETED'));

ALTER TABLE "appointments" ADD CONSTRAINT "appointments_valid_interval" CHECK ("endsAt" > "startsAt");
ALTER TABLE "services" ADD CONSTRAINT "services_duration_positive" CHECK ("durationMinutes" > 0 AND "bufferMinutes" >= 0);
ALTER TABLE "services" ADD CONSTRAINT "services_price_non_negative" CHECK ("priceMinor" >= 0 AND "depositMinor" >= 0 AND "depositMinor" <= "priceMinor");
ALTER TABLE "payments" ADD CONSTRAINT "payments_amount_positive" CHECK ("amountMinor" > 0);
ALTER TABLE "work_schedules" ADD CONSTRAINT "work_schedules_valid" CHECK ("weekday" BETWEEN 1 AND 7 AND "endMinute" > "startMinute" AND "startMinute" >= 0 AND "endMinute" <= 2880);
