# Image for the container providers (Railway, Fly). Render and Vercel build the site natively and serve it from
# their CDNs, so they do not use this file.
FROM node:24.22.3-slim AS build
WORKDIR /app
# Only the install inputs, so a source change keeps the install layer.
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
# Declared after the install, so a new commit does not invalidate the install layer.
ARG BENCH_COMMIT
ARG RAILWAY_GIT_COMMIT_SHA
RUN sh ./bench/build.sh build

FROM caddy:2.11.9-alpine
# BusyBox `date` has no %N; the runtime markers need milliseconds.
RUN apk add --no-cache coreutils
COPY Caddyfile /etc/caddy/Caddyfile
COPY bench/serve.sh /bench/serve.sh
COPY --from=build /app/website/build /srv
ENV PORT=80
CMD ["sh", "/bench/serve.sh"]
