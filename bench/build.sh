#!/bin/sh
set -eu

# Each marker carries the wall-clock time in epoch milliseconds, so a parser does not depend on the time at which
# the provider received the log line. A `date` without %N (BusyBox, macOS) falls back to whole seconds.
mark() {
  now="$(date +%s%3N)"
  case "$now" in *[!0-9]*) now="$(date +%s)000" ;; esac
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

OUT=website/build

install() {
  # Print the versions before the marker: on Render the first `node` call installs Node. That is toolchain setup,
  # which other providers do before the install step.
  node --version
  yarn --version
  mark install_start
  yarn install --frozen-lockfile --non-interactive
  mark install_done
}

build() {
  mark build_start
  yarn build
  # A CDN cannot answer from runtime env, so the build writes the deployment identity as a file that is served at
  # /version. BENCH_RUN_ID reaches the build on Render (service env) and Vercel (--build-env). In the container
  # (Railway, Fly), bench/serve.sh writes the file again from the runtime env.
  printf '{"commit":"%s","run":"%s"}\n' "$(commit_sha)" "${BENCH_RUN_ID:-unknown}" > "$OUT/version"
  mark build_done
}

case "${1:-all}" in
  install) install ;;
  build) build ;;
  all) install; build ;;
  *) printf 'Usage: %s {install|build|all}\n' "$0" >&2; exit 2 ;;
esac
