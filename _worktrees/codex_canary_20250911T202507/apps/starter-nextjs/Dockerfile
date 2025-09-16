# syntax=docker/dockerfile:1.7
ARG NODE_VERSION=20-alpine
FROM node:${NODE_VERSION} AS deps
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.pnpm-store \
    if [ -f pnpm-lock.yaml ]; then corepack enable && pnpm i --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    else npm ci; fi
COPY . .
FROM deps AS build
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.pnpm-store \
    if [ -f pnpm-lock.yaml ]; then pnpm build; \
    elif [ -f yarn.lock ]; then yarn build; \
    else npm run build; fi
FROM node:${NODE_VERSION} AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/public ./public
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --retries=6 CMD nc -z 127.0.0.1 3000 || exit 1
CMD ["node","server.js"]
