# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS build
WORKDIR /repo
RUN corepack enable
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/booking-web/package.json apps/booking-web/
RUN pnpm install --frozen-lockfile --filter @beauty-crm/booking-web...
COPY apps/booking-web apps/booking-web
RUN cd apps/booking-web && NEXT_TELEMETRY_DISABLED=1 pnpm build

FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production PORT=3001 HOSTNAME=0.0.0.0
COPY --from=build /repo/apps/booking-web/.next/standalone ./
COPY --from=build /repo/apps/booking-web/.next/static ./apps/booking-web/.next/static
USER node
EXPOSE 3001
CMD ["node", "apps/booking-web/server.js"]
