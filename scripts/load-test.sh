#!/usr/bin/env bash
# Trigger the HPA. Prefers 'hey' if installed, else falls back to a curl loop.
# Usage: ./scripts/load-test.sh http://<alb-dns> [concurrency] [seconds] [busy_ms]
set -euo pipefail

URL="${1:?Usage: load-test.sh <url> [concurrency] [seconds] [busy_ms]}"
CONC="${2:-50}"
SECS="${3:-180}"
BUSY="${4:-200}"
TARGET="${URL%/}/load?ms=$BUSY"

echo "Hammering $TARGET (concurrency=$CONC, ${SECS}s)"
echo "Watch: kubectl -n projectx get hpa,pods -w"

if command -v hey >/dev/null 2>&1; then
  hey -z "${SECS}s" -c "$CONC" "$TARGET"
else
  echo "(hey not found; using curl fan-out)"
  end=$(( $(date +%s) + SECS ))
  for _ in $(seq 1 "$CONC"); do
    ( while [ "$(date +%s)" -lt "$end" ]; do curl -s -o /dev/null "$TARGET" || true; done ) &
  done
  wait
fi
echo "Done. Final: kubectl -n projectx get hpa,pods"
