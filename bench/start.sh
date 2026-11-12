#!/bin/sh
set -eu

# Start command of the Caddy image (Railway and Fly). It prints the runtime markers, which a static CDN deploy has no
# equivalent for. BusyBox `date` in the Caddy image has no %N, so these markers have whole-second precision.
mark() {
  now="$(date +%s%3N)"
  # BusyBox prints the seconds without an error, so check for 13 digits.
  case "$now" in *[!0-9]*) now="$(date +%s)000" ;; esac
  [ "${#now}" -eq 13 ] || now="$(date +%s)000"
  printf '::bench::%s %s\n' "$1" "$now"
}

mark start
BENCH_COMMIT="$(cat /etc/bench-commit)"
export BENCH_COMMIT
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
caddy_pid=$!
# Caddy logs no single line for "accepting connections", so poll the port.
until wget -q -O /dev/null "http://127.0.0.1:${PORT}/version" 2>/dev/null; do
  kill -0 "$caddy_pid" 2>/dev/null || wait "$caddy_pid"
  sleep 0.1
done
mark listening
trap 'kill -TERM "$caddy_pid"' TERM INT
wait "$caddy_pid"
