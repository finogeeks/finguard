#!/usr/bin/env sh
# Post-try.sh integration checks against a running public lab (no image rebuild).
#
#   ./try.sh
#   ./lab-exercises.sh
#
# Requires the Compose project from try.sh (default: finguard-try).
set -eu

COMPOSE_PROJECT="${FINGUARD_COMPOSE_PROJECT:-finguard-try}"
PACK_DIR_DEFAULT="${HOME}/.finguard-try"
ADMIN_TOKEN="${FINGUARD_ADMIN_TOKEN:-local-compose-token}"
HTTP="${FINGUARD_HTTP:-http://127.0.0.1:19191}"
GW="${FINGUARD_GATEWAY:-http://127.0.0.1:13000}"
ERP="${FINGUARD_MOCK_ERP:-http://127.0.0.1:18080}"

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$1" >&2
}

usage() {
  cat <<'EOF' >&2
Usage:
  lab-exercises.sh [--help]

Run after ./try.sh. Checks:
  1. GET /v1/journal without Bearer → 401
  2. GET /v1/journal with admin Bearer is JSON
  3. POST /v1/audit/verify → ok
  4. Agent-shaped POST :13000/writes + replay holds count
  5. Fail-closed: FinGuard stopped → write does not land on mock ERP
  6. POST /v1/action-manifests for /writes

Environment:
  FINGUARD_COMPOSE_PROJECT  Compose project (default: finguard-try)
  FINGUARD_PACK_DIR         Public pack root if not next to this script
  FINGUARD_SKIP_FAILCLOSED  Set to 1 to skip the stop/start FinGuard step

Chinese: docs/lab.zh.md
English: docs/lab.md
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd curl
need_cmd python3
need_cmd docker

if docker compose version >/dev/null 2>&1; then
  compose() { docker compose "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
  compose() { docker-compose "$@"; }
else
  die "docker compose is required"
fi

resolve_script_dir() {
  case "$0" in
    sh|bash|dash|zsh|"")
      echo ""
      return
      ;;
  esac
  if [ -f "$0" ]; then
    CDPATH= cd "$(dirname "$0")" && pwd
    return
  fi
  echo ""
}

find_compose_file() {
  dir="$1"
  if [ -f "$dir/distribution/compose/docker-compose.yml" ]; then
    echo "$dir/distribution/compose/docker-compose.yml"
    return 0
  fi
  return 1
}

SCRIPT_DIR="$(resolve_script_dir)"
COMPOSE_FILE=""
if [ -n "$SCRIPT_DIR" ] && find_compose_file "$SCRIPT_DIR" >/dev/null; then
  COMPOSE_FILE="$(find_compose_file "$SCRIPT_DIR")"
elif [ -n "${FINGUARD_PACK_DIR:-}" ] && find_compose_file "$FINGUARD_PACK_DIR" >/dev/null; then
  COMPOSE_FILE="$(find_compose_file "$FINGUARD_PACK_DIR")"
elif find_compose_file "$PACK_DIR_DEFAULT" >/dev/null; then
  COMPOSE_FILE="$(find_compose_file "$PACK_DIR_DEFAULT")"
else
  die "cannot find distribution/compose/docker-compose.yml (run ./try.sh first, or set FINGUARD_PACK_DIR)"
fi

compose_lab() {
  compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT" --profile greenfield "$@"
}

curl -fsS -m 2 "$GW/healthz" >/dev/null 2>&1 || die "lab is not up on ${GW}/healthz — run ./try.sh first"

info "1/6 journal without token is 401"
code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$HTTP/v1/journal")"
[ "$code" = "401" ] || die "expected 401 from unauthenticated /v1/journal, got ${code}"

info "2/6 journal with admin token"
curl -fsS -m 5 -H "Authorization: Bearer ${ADMIN_TOKEN}" "$HTTP/v1/journal" \
  | python3 -c 'import json,sys; json.load(sys.stdin)'

info "3/6 audit verify"
curl -fsS -m 5 -H "Authorization: Bearer ${ADMIN_TOKEN}" -X POST "$HTTP/v1/audit/verify" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("ok") is True, d'

info "4/6 agent-shaped write + replay"
key="lab-$(date +%s)-$$"
before="$(curl -fsS -m 5 "$ERP/writes" | python3 -c 'import json,sys; print(json.load(sys.stdin)["writes"])')"
curl -fsS -m 5 -X POST "$GW/writes" \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${key}" \
  -d "{\"batch\":\"allow\",\"run\":\"${key}\"}" >/dev/null
curl -fsS -m 5 -X POST "$GW/writes" \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${key}" \
  -d "{\"batch\":\"allow\",\"run\":\"${key}\"}" >/dev/null
after="$(curl -fsS -m 5 "$ERP/writes" | python3 -c 'import json,sys; print(json.load(sys.stdin)["writes"])')"
python3 -c "b=int('${before}'); a=int('${after}'); assert a==b+1, (b,a)"

if [ "${FINGUARD_SKIP_FAILCLOSED:-0}" != "1" ]; then
  info "5/6 fail-closed (stop FinGuard)"
  writes_before="$(curl -fsS -m 5 "$ERP/writes" | python3 -c 'import json,sys; print(json.load(sys.stdin)["writes"])')"
  compose_lab stop finguard >/dev/null
  set +e
  fc_code="$(curl -s -o /dev/null -w '%{http_code}' -m 8 -X POST "$GW/writes" \
    -H 'content-type: application/json' \
    -H "Idempotency-Key: failclosed-${key}" \
    -d '{"batch":"allow","run":"failclosed"}')"
  fc_curl=$?
  set -e
  writes_during="$(curl -fsS -m 5 "$ERP/writes" | python3 -c 'import json,sys; print(json.load(sys.stdin)["writes"])')"
  compose_lab start finguard >/dev/null
  ready=0
  i=0
  while [ "$i" -lt 40 ]; do
    if curl -fsS -m 2 "$GW/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    i=$((i + 1))
    sleep 1
  done
  [ "$ready" = "1" ] || die "FinGuard did not become ready after fail-closed restart"
  [ "$writes_during" = "$writes_before" ] || die "fail-closed leaked a mock ERP write (${writes_before} -> ${writes_during})"
  if [ "$fc_curl" -eq 0 ] && [ "$fc_code" = "200" ]; then
    die "fail-closed: gateway still returned HTTP 200 while FinGuard was stopped"
  fi
  echo "OK: fail-closed (gateway http=${fc_code:-curl-fail}; erp writes unchanged)"
else
  info "5/6 fail-closed skipped (FINGUARD_SKIP_FAILCLOSED=1)"
fi

info "6/6 register action manifest"
curl -fsS -m 5 -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H 'content-type: application/json' \
  -d '{
    "schema_version": 1,
    "service": "erp",
    "action_id": "erp.invoice.pay",
    "version": "1",
    "display_name": "Pay invoice",
    "protocol": {"kind": "rest", "method": "POST", "path": "/writes"},
    "risk": {"level": "high", "kind": "w"},
    "approval": {},
    "auth": {"mode": "obo_user"}
  }' \
  "$HTTP/v1/action-manifests" >/dev/null

cat <<EOF

OK: lab exercises passed.

Point an HTTP agent at ${GW} (path /writes). Do not give it ${ERP}.
Admin: Authorization: Bearer ${ADMIN_TOKEN}

This lab is stub identity + mock ERP. Cluster/IdP: docs/install-cluster.md
中文手册: docs/lab.zh.md
EOF
