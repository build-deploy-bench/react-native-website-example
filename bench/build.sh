#!/bin/sh
set -eu

# Each marker carries the wall-clock time in epoch milliseconds, so a parser does not depend on the time at which
# the provider received the log line. A `date` without %N (BusyBox) falls back to whole seconds.
mark() {
  now="$(date +%s%3N)"
  # BusyBox prints the seconds without an error, so check for 13 digits.
  case "$now" in *[!0-9]*) now="$(date +%s)000" ;; esac
  [ "${#now}" -eq 13 ] || now="$(date +%s)000"
  printf '::bench::%s %s\n' "$1" "$now"
}

# The commit is fixed at build time. BENCH_COMMIT is the harness override (Fly passes it as a build arg); the others
# are provider variables. The source upload of Fly and Vercel has no .git, so `git` is the last fallback only.
commit_sha() {
  for sha in "${BENCH_COMMIT:-}" "${RENDER_GIT_COMMIT:-}" "${RAILWAY_GIT_COMMIT_SHA:-}" "${VERCEL_GIT_COMMIT_SHA:-}"; do
    if [ -n "$sha" ]; then
      printf '%s\n' "$sha"
      return
    fi
  done
  git rev-parse HEAD 2>/dev/null || printf '%s\n' unknown
}

install() {
  mark install_start
  node --version
  yarn --version
  yarn install --frozen-lockfile --non-interactive
  mark install_done
}

build() {
  mark build_start
  yarn build
  # The CDN providers (Render, Vercel) serve this file at /version, so the run ID must be known at build time.
  # The Caddy image answers /version from its runtime env instead and ignores this file.
  printf '{"commit":"%s","run":"%s"}\n' "$(commit_sha)" "${BENCH_RUN_ID:-unknown}" > website/build/version.json
  mark build_done
}

case "${1:-all}" in
  install) install ;;
  build) build ;;
  all) install; build ;;
  *) printf 'Usage: %s {install|build|all}\n' "$0" >&2; exit 2 ;;
esac
