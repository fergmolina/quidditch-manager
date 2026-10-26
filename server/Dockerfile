# syntax=docker/dockerfile:1
# Accounts API for the browser build. Build context: the repository root, because the web strings are generated
# from locale/strings.csv, which sits next to server/ (Dockerfile.dockerignore keeps the context to the files below):
#   docker build -f server/Dockerfile -t qm-api .

FROM node:24-bookworm-slim AS build
# scripts/gen-i18n.ts resolves the CSV as ../../locale/strings.csv, hence the repo-like layout under /src.
WORKDIR /src/server
COPY server/package.json server/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY server/tsconfig.json server/tsconfig.build.json ./
COPY server/src ./src
# src/career/report.ts and src/pages/ranking.ts import these as ../../../data/shared/*.json; at runtime dist/career and
# dist/pages resolve them to /data/shared.
COPY data/shared/career_rules.json data/shared/season_report.schema.json data/shared/map.json /src/data/shared/
COPY server/scripts/gen-i18n.ts ./scripts/
COPY locale/strings.csv /src/locale/strings.csv
RUN npm run gen:i18n
RUN npm run build && npm prune --omit=dev --ignore-scripts

FROM node:24-bookworm-slim
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8080
WORKDIR /app
COPY --from=build --chown=root:root /src/server/node_modules ./node_modules
COPY --from=build --chown=root:root /src/server/dist ./dist
COPY --from=build --chown=root:root /src/server/generated/strings.json ./generated/strings.json
COPY --chown=root:root server/package.json ./
COPY --chown=root:root server/static ./static
COPY --chown=root:root server/legal ./legal
COPY --chown=root:root server/migrations ./migrations
# Location picklists (GeoNames, CC BY 4.0), built by scripts/build-geo.ts and committed.
COPY --chown=root:root server/data ./data
COPY --chown=root:root data/shared/career_rules.json data/shared/season_report.schema.json data/shared/map.json /data/shared/
# Runs as the image's unprivileged `node` user; nothing under /app is writable by it, and the app writes no files,
# so the container can run with a read-only root filesystem (compose: read_only: true, cap_drop: [ALL]).
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
CMD ["node", "dist/index.js"]
