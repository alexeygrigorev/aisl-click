#!/usr/bin/env bash
# Poll until the .click registry delegates aisl.click to the CF-managed edge zone.
# Uses `dig +trace` (authoritative, bypasses resolver cache) so it reflects the
# actual registry state. Exits 0 once propagated; logs each check.
set -uo pipefail

WANT="ns-1502.awsdns-59.org"
for i in $(seq 1 40); do
  # +trace follows root -> .click TLD -> delegation; grep our NS in the result.
  TRACE=$(dig +trace +nodnssec NS aisl.click 2>/dev/null || true)
  if echo "$TRACE" | grep -q "$WANT"; then
    echo "[$(date +%H:%M:%S)] PROPAGATED — .click registry now delegates to my zone"
    echo "$TRACE" | grep -iE "aisl\.click\..*IN\tNS" | sort -u
    echo "---"
    echo "resolver check (1.1.1.1):"
    dig +short NS aisl.click @1.1.1.1 | sort
    exit 0
  fi
  echo "[$(date +%H:%M:%S)] check $i: still old NS (registry propagating)"
  sleep 180
done
echo "[$(date +%H:%M:%S)] giving up after ~2h; manual re-check needed"
exit 1
