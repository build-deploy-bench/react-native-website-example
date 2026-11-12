# Caddy image for Railway and Fly, which have no static hosting product. Railway selects this file with
# RAILWAY_DOCKERFILE_PATH and Fly with fly.toml; Render and Vercel build natively and ignore it.
FROM node:24-slim AS build
WORKDIR /app

# Install and build are separate RUN steps so the ::bench:: markers and BuildKit step times stay separable.
# Manifests are copied first so a warm layer cache can skip the install step.
COPY package.json yarn.lock .yarnrc ./
COPY .yarn/releases .yarn/releases
COPY website/package.json website/package.json
COPY packages/lint-examples/package.json packages/lint-examples/package.json
COPY plugins/remark-codeblock-language-as-title/package.json plugins/remark-codeblock-language-as-title/package.json
COPY plugins/remark-lint-no-dead-urls/package.json plugins/remark-lint-no-dead-urls/package.json
COPY plugins/remark-snackplayer/package.json plugins/remark-snackplayer/package.json
COPY bench/build.sh bench/build.sh
RUN sh ./bench/build.sh install

COPY . .
# The provider passes the commit as a build arg (Railway: RAILWAY_GIT_COMMIT_SHA; Fly: the harness sets
# BENCH_COMMIT). Declared after the install step, so a new commit does not invalidate the install layer.
ARG BENCH_COMMIT
ARG RAILWAY_GIT_COMMIT_SHA
RUN sh ./bench/build.sh build

FROM caddy:2-alpine
ENV PORT=80
COPY bench/Caddyfile /etc/caddy/Caddyfile
COPY bench/start.sh /usr/local/bin/bench-start
COPY --from=build /app/website/build /srv
# build.sh wrote the commit into version.json. Keep it outside the site root for the start script, which serves
# /version from env.
RUN sed -n 's/.*"commit":"\([^"]*\)".*/\1/p' /srv/version.json > /etc/bench-commit
EXPOSE 80
CMD ["sh", "/usr/local/bin/bench-start"]
