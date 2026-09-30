# ── Stage 1: upstream source + patches BEFORE compile ──────────────────────
# Clones the official OmniRoute repo (NOT a fork) at a pinned tag and applies
# local patches to the TypeScript source. Patching here (pre-build) is what
# makes the patches actually take effect: the official image is shipped
# compiled, so patching .ts files on a built image does nothing.
FROM alpine/git AS source
RUN apk add --no-cache patch
ARG OMNROUTE_VERSION=v3.8.51
# v3.8.51 tag == c1e30b7676975feb298b49eff6ff58923c04b89e (verified 2026-09-30).
# Tags are immutable; if a rebuild needs the exact same source, this SHA pins it.
RUN git clone --depth 1 --branch ${OMNROUTE_VERSION} \
    https://github.com/diegosouzapw/OmniRoute.git /src
# Add future patches here. Numeric prefixes fix the application order (the
# `for` loop globs /patches/*.patch alphabetically).
# NOTES as of v3.8.51:
#  - upstream #11234 (opencodeGo dashboard snapshot bridge) and #9353 are in.
#  - v3.8.51 replaced the opencode cookie/dashboard scraper with the official
#    API endpoint (GET /zen/go/v1/usage), so no scraper patch is needed.
#  - reset-aware is still session+weekly only; quotaCache still drops non-oauth
#    entries on refresh and getQuotaCache still misses SQLite snapshots.
# Re-check every patch with `patch --dry-run` after each upstream bump.
COPY 01-reset-aware-monthly.patch /patches/01-reset-aware-monthly.patch
COPY 02-quota-refresh-apikey.patch /patches/02-quota-refresh-apikey.patch
# 03 builds on 01 (same file) and must be applied after it: adds the optional
# per-combo "pace" scoring for the monthly window (config.resetAwareMonthlyMode).
# Default stays "pressure", so existing combos keep their behavior until the
# mode is set explicitly on a combo.
COPY 03-reset-aware-monthly-pace.patch /patches/03-reset-aware-monthly-pace.patch
# 04 maps provider-native quota window names to canonical structural windows:
# command-code credits->monthly and five_hour->5h, plus opencode's mcp_monthly
# as a monthly alias (so the account-level paths see the monthly window too).
COPY 04-provider-quota-window-aliases.patch /patches/04-provider-quota-window-aliases.patch
RUN cd /src && for p in /patches/*.patch; do patch -p1 < "$p"; done

# ── Stage 2: base (replica of the official Dockerfile's `base` stage) ──────
FROM node:26-trixie-slim AS base
WORKDIR /app

# Security-patched versions of the Debian (trixie) base-image packages at build time.
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,id=apt-lists,target=/var/lib/apt/lists,sharing=locked \
  apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends libsecret-1-0 ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Refresh the globally-installed npm so its bundled node_modules ship patched versions.
RUN npm install -g npm@latest \
  && npm cache clean --force

# ── Stage 3: builder (replica of the official Dockerfile's `builder` stage) ─
FROM base AS builder

# Next.js build-time telemetry off (upstream sets this in the builder stage).
ENV NEXT_TELEMETRY_DISABLED=1

# Build tools for native module compilation.
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,id=apt-lists,target=/var/lib/apt/lists,sharing=locked \
  apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY --from=source /src/package*.json ./
# Workspace package manifests MUST be present before `npm ci` (open-sse deps).
COPY --from=source /src/open-sse/package.json ./open-sse/package.json
COPY --from=source /src/scripts/build/postinstall.mjs ./scripts/build/postinstall.mjs
COPY --from=source /src/scripts/build/postinstallSupport.mjs ./scripts/build/postinstallSupport.mjs
COPY --from=source /src/scripts/build/native-binary-compat.mjs ./scripts/build/native-binary-compat.mjs
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true
RUN test -f package-lock.json \
  || (echo "package-lock.json is required for reproducible Docker builds" >&2 && exit 1)
# --ignore-scripts blocks broad install/postinstall hooks (supply-chain); rebuild
# only the known native runtime deps explicitly. better-sqlite3 needs a native
# binding for the target platform; wreq-js (TLS impersonation, v3.8.51 replaced
# tls-client-node with it) ships a prebuilt native addon that must load at build
# time so a broken/rate-limited fetch fails the build loudly instead of shipping
# a broken image.
RUN --mount=type=cache,id=npm-cache,target=/root/.npm \
  npm ci --include=optional --no-audit --no-fund --legacy-peer-deps --ignore-scripts \
  && (cd node_modules/better-sqlite3 \
      && node /usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --force_build=1) \
  && test -f node_modules/better-sqlite3/build/Release/better_sqlite3.node \
  && node -e "require('better-sqlite3')(':memory:').close()" \
  && node -e "const wreq=require('wreq-js'); if(typeof wreq.createTransport!=='function') process.exit(1)"

# Turbopack's native (Rust) memory is NOT bounded by --max-old-space-size, and
# the 16GB GitHub CI runners OOM during `npm run build` with it enabled. Use the
# webpack fallback (bounded by the V8 heap) for memory-constrained CI runners.
# Override with --build-arg OMNIROUTE_USE_TURBOPACK=1 on a large-memory machine.
ARG OMNIROUTE_USE_TURBOPACK=0
ENV OMNIROUTE_USE_TURBOPACK=$OMNIROUTE_USE_TURBOPACK

# Next.js basePath is fixed at build time.
ARG OMNIROUTE_BASE_PATH=""
ENV OMNIROUTE_BASE_PATH=$OMNIROUTE_BASE_PATH

# Docker containers cannot run the MITM/Agent-Bridge stack; keep the graceful stub.
ENV OMNIROUTE_MITM_STUB=1

# Raise the V8 heap ceiling for the build. The webpack production pass peaks
# ~3.9 GB (brushes a 4 GB ceiling); upstream uses 6144 on 16 GB runners.
ARG OMNIROUTE_BUILD_MEMORY_MB=6144
ENV NODE_OPTIONS="--max-old-space-size=${OMNIROUTE_BUILD_MEMORY_MB}"

# Cap the Next.js page-data worker pool. Next 16 derives the worker count from
# CIRCLE_NODE_TOTAL (workers = N-1); on a 16 GB runner the default (many
# workers, each inheriting NODE_OPTIONS) exhausts memory and buildkit fails with
# `ResourceExhausted: cannot allocate memory`. 2 => a single worker process.
ARG OMNIROUTE_BUILD_WORKERS=2
ENV CIRCLE_NODE_TOTAL=${OMNIROUTE_BUILD_WORKERS}

COPY --from=source /src ./
RUN --mount=type=cache,id=next-cache,target=/app/.build/next/cache \
  mkdir -p /app/data && npm run build

# ── Stage 4: runner (replica of the official Dockerfile's `runner-base`) ────
FROM base AS runner

LABEL org.opencontainers.image.title="Home Assistant App: OmniRoute" \
  org.opencontainers.image.description="Unified AI proxy. Route any LLM through one endpoint." \
  org.opencontainers.image.source="https://github.com/grunjol/addon-omniroute" \
  org.opencontainers.image.licenses="MIT"

ENV NODE_ENV=production
ENV PORT=20128
ENV HOSTNAME=0.0.0.0
# Runtime heap ceiling (override via -e OMNIROUTE_MEMORY_MB=2048).
ENV OMNIROUTE_MEMORY_MB=1024
ENV NODE_OPTIONS="--max-old-space-size=${OMNIROUTE_MEMORY_MB}"

# Data directory inside Docker — must match the addon config map.
ENV DATA_DIR=/app/data
RUN mkdir -p /app/data

# `npm run build` (build-next-isolated -> assembleStandalone) bundles ALL runtime
# files into .build/next/standalone/. Copy the COMPLETE standalone output.
COPY --from=builder /app/.build/next/standalone ./
# better-sqlite3: guarantee the complete package (JS wrapper + native binding).
COPY --from=builder /app/node_modules/better-sqlite3 ./node_modules/better-sqlite3
# migrations land at <standalone>/migrations via assembleStandalone.
ENV OMNIROUTE_MIGRATIONS_DIR=/app/migrations

# Docker healthcheck script (not traced by Next.js standalone output).
COPY --from=builder /app/scripts/dev/healthcheck.mjs ./healthcheck.mjs

# Home Assistant mounts addon_config as root-owned, so the addon runs as root
# (the upstream image runs as `node`, which cannot write to the HA-mounted data
# dir). Dropping the chown also avoids the ~130MB duplicate layer it created.
EXPOSE 20128

USER root

# Warns if the mounted data volume has wrong ownership.
COPY --from=source --chmod=755 /src/scripts/check-permissions.sh /tmp/check-permissions.sh
ENTRYPOINT ["/tmp/check-permissions.sh"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["node", "healthcheck.mjs"]

CMD ["node", "dev/run-standalone.mjs"]
