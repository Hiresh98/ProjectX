# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────
# build: install deps and produce the static Vite bundle.
# VITE_* values are baked in at BUILD time (they end up in the public bundle),
# so they are passed as build args, not runtime env.
# ──────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

ARG VITE_API_BASE_URL=/api/v1
ARG VITE_APP_NAME="ProjectX RBAC"
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_APP_NAME=$VITE_APP_NAME

COPY . .
RUN npm run build

# ──────────────────────────────────────────────────────────────────────────
# runner: serve the static files with a non-root nginx (listens on :8080) and
# reverse-proxy /api/* to the backend.
# ──────────────────────────────────────────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runner
USER root
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=build /app/dist /usr/share/nginx/html
# The entrypoint renders the final conf at start, so conf.d must be writable
# by the non-root nginx user.
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown -R nginx:nginx /etc/nginx/conf.d
USER nginx

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
