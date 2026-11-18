#!/usr/bin/env bash
# Perimeter tests for infra/nginx/nginx.conf (needs Docker).
#   unit:        nginx -t syntax check
#   integration: rate limiting on /api/auth/ (10 req/s per IP -> 429), HTTP->HTTPS redirect
#   e2e:         HTTPS traffic through the gateway: security headers, gzip, /health latency
# Usage: bash infra/nginx/tests/run.sh
set -uo pipefail
export MSYS_NO_PATHCONV=1

# Docker Desktop on Windows needs host-style paths for bind mounts
hostpath() { cygpath -m "$1" 2>/dev/null || echo "$1"; }

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="nginx:alpine"
NET="aa-nginx-test-$$"
WORK="$(mktemp -d)"
FAILS=0
CONF="$(hostpath "$HERE/../nginx.conf")"
STUB="$(hostpath "$HERE/stub.conf")"
WORK_H="$(hostpath "$WORK")"

cleanup() {
  docker rm -f "$NET-stub" "$NET-gw" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT


check() { # check <name> <condition-exit-code>
  if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS + 1)); fi
}

# Self-signed cert at the path nginx.conf expects (Let's Encrypt layout)
CERT_DIR="$WORK/live/alientoandino.org"
mkdir -p "$CERT_DIR" "$WORK/data"
head -c 3000 /dev/zero | tr '\0' 'x' > "$WORK/data/big.txt"
docker run --rm -v "$(hostpath "$CERT_DIR"):/out" "$IMAGE" sh -c \
  "apk add -q openssl >/dev/null && openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
   -subj /CN=localhost -keyout /out/privkey.pem -out /out/fullchain.pem" >/dev/null 2>&1

docker network create "$NET" >/dev/null
docker run -d --name "$NET-stub" --network "$NET" \
  --network-alias backend --network-alias web --network-alias docs --network-alias ml \
  -v "$STUB:/etc/nginx/nginx.conf:ro" -v "$WORK_H/data:/data:ro" "$IMAGE" >/dev/null

run_gw() {
  docker run "$@" --network "$NET" \
    -v "$CONF:/etc/nginx/nginx.conf:ro" -v "$WORK_H:/etc/letsencrypt:ro" "$IMAGE"
}

# --- Unit: syntax ---
docker run --rm --network "$NET" -v "$CONF:/etc/nginx/nginx.conf:ro" -v "$WORK_H:/etc/letsencrypt:ro" "$IMAGE" nginx -t >/dev/null 2>&1; check "unit: nginx -t" $?

# --- Start gateway ---
run_gw -d --name "$NET-gw" -p 127.0.0.1::80 -p 127.0.0.1::443 >/dev/null
sleep 2
if [ "$(docker inspect -f '{{.State.Running}}' "$NET-gw")" != "true" ]; then
  echo "gateway failed to start:"; docker logs "$NET-gw" 2>&1 | tail -5; exit 1
fi
HTTP_PORT="$(docker port "$NET-gw" 80/tcp | head -1 | sed 's/.*://')"
HTTPS_PORT="$(docker port "$NET-gw" 443/tcp | head -1 | sed 's/.*://')"
H="https://127.0.0.1:$HTTPS_PORT"

# --- Integration: HTTP redirects to HTTPS, /health stays on HTTP ---
code="$(curl -s -o "$WORK_H/body" -w '%{http_code}' "http://127.0.0.1:$HTTP_PORT/")"
[ "$code" = "301" ]; check "integration: http -> https redirect (301)" $?
code="$(curl -s -o "$WORK_H/body" -w '%{http_code}' "http://127.0.0.1:$HTTP_PORT/health")"
[ "$code" = "200" ]; check "integration: GET /health over http is 200" $?

# --- Integration: rate limiting on auth (burst of 40 parallel requests) ---
codes="$(seq 40 | xargs -P 40 -I{} curl -sk -o "$WORK_H/body" -w '%{http_code}\n' "$H/api/auth/login")"
echo "      burst status codes: $(echo "$codes" | sort | uniq -c | tr "
" " ")"
n429="$(echo "$codes" | grep -c "^429")"; n200="$(echo "$codes" | grep -c "^200")"
[ "${n429:-0}" -gt 0 ] && [ "${n200:-0}" -gt 0 ]
check "integration: /api/auth/ burst gives 200s then 429s (200=${n200:-0}, 429=${n429:-0})" $?

sleep 2 # let the limiter bucket drain before the e2e checks
# --- E2E: HTTPS ---
HDRS="$(curl -skI "$H/health")"
echo "$HDRS" | grep -qiE '^x-frame-options: DENY'; check "e2e: X-Frame-Options DENY" $?
echo "$HDRS" | grep -qiE '^x-content-type-options: nosniff'; check "e2e: X-Content-Type-Options nosniff" $?
echo "$HDRS" | grep -qiE '^strict-transport-security: .*max-age=63072000'; check "e2e: HSTS" $?
echo "$HDRS" | grep -qiE "^content-security-policy: default-src 'self'"; check "e2e: CSP" $?
# Median of 11 samples of time-to-first-byte after the TLS handshake (excludes TCP/TLS setup)
ms="$(for _ in $(seq 11); do
  curl -sk -o "$WORK_H/body" -w '%{time_starttransfer} %{time_appconnect}\n' "$H/health"
done | awk '{printf "%d\n", ($1-$2)*1000}' | sort -n | sed -n 6p)"
[ "$ms" -lt 20 ]; check "e2e: GET /health < 20ms (median ${ms}ms)" $?
curl -sk "$H/health" | grep -qE '^ok'; check "e2e: GET /health proxied over https" $?
if curl -V | grep -qE 'HTTP2'; then
  proto="$(curl -sk -o "$WORK_H/body" -w '%{http_version}' --http2 "$H/health")"
  [ "$proto" = "2" ]; check "e2e: HTTP/2 negotiated" $?
else
  echo "SKIP  e2e: HTTP/2 negotiated (local curl lacks HTTP/2)"
fi
GZ="$(curl -sk -H 'Accept-Encoding: gzip' -D - -o "$WORK_H/body" "$H/api/big.txt")"
echo "$GZ" | grep -qiE '^content-encoding: gzip' || echo "$GZ" | head -8
echo "$GZ" | grep -qiE '^content-encoding: gzip'
check "e2e: gzip on large text responses" $?

echo
if [ "$FAILS" -eq 0 ]; then echo "All nginx perimeter checks passed."; else echo "$FAILS check(s) failed."; exit 1; fi
