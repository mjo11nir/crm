# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS build
WORKDIR /repo
RUN corepack enable
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY services/api/package.json services/api/
RUN pnpm install --frozen-lockfile --filter @beauty-crm/api...
COPY services/api services/api
RUN cd services/api && npx prisma generate && pnpm build

FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
# keep the pnpm workspace layout so node_modules symlinks stay valid
COPY --from=build /repo /repo
WORKDIR /repo/services/api
USER node
EXPOSE 3000
# Apply migrations, then start. Run migrations as a separate release step in production.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
