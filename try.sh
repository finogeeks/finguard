#!/usr/bin/env sh
# Bring up a FinGuard laptop lab from GHCR (Compose: product image + mock ERP + Postgres).
#
# One-liner (after finogeeks/finguard exists on GitHub):
#   curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
#
# From a checkout of this pack:
#   ./try.sh
#   ./try.sh --down
#
# This is a lab. Mock ERP + bundled Postgres + unsigned image.
# It does not prove a customer IdP or a real ERP.
set -eu

REPO_DEFAULT="finogeeks/finguard"
REPO="${FINGUARD_REPO:-$REPO_DEFAULT}"
VERSION_RAW="${FINGUARD_VERSION:-0.1.0}"
PACK_DIR_DEFAULT="${HOME}/.finguard-try"
IMAGE_NS="${FINGUARD_IMAGE_NS:-ghcr.io/finogeeks}"
SKIP_PULL="${FINGUARD_SKIP_PULL:-0}"
COMPOSE_PROJECT="${FINGUARD_COMPOSE_PROJECT:-finguard-try}"

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$1" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

strip_v() {
  echo "$1" | sed 's/^v//'
}

usage() {
  cat <<'EOF' >&2
Usage:
  try.sh [--version <x.y.z>] [--down] [--help]

Environment:
  FINGUARD_VERSION          Image/pack version (default: 0.1.0)
  FINGUARD_REPO             GitHub owner/name to clone when not in a pack (default: finogeeks/finguard)
  FINGUARD_PACK_DIR         Where to clone the public pack (default: ~/.finguard-try)
  FINGUARD_IMAGE_NS         Registry namespace (default: ghcr.io/finogeeks)
  FINGUARD_SKIP_PULL        Set to 1 to use images already present locally
  FINGUARD_COMPOSE_PROJECT  Compose project name (default: finguard-try)

Examples:
  curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
  ./try.sh --version 0.1.0
  FINGUARD_SKIP_PULL=1 ./try.sh
  ./try.sh --down

Chinese docs: docs/getting-started.zh.md  docs/lab.zh.md
EOF
}

ACTION=up
VERSION="$VERSION_RAW"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --down)
      ACTION=down
      shift
      ;;
    --version)
      [ $# -ge 2 ] || die "--version requires an argument"
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#--version=}"
      shift
      ;;
    *)
      die "unknown argument: $1 (see --help)"
      ;;
  esac
done

VERSION="$(strip_v "$VERSION")"
[ -n "$VERSION" ] || die "empty version"

need_cmd docker
need_cmd curl
if docker compose version >/dev/null 2>&1; then
  compose() { docker compose "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
  compose() { docker-compose "$@"; }
else
  die "docker compose is required (Docker Compose v2 plugin or docker-compose)"
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
PACK_DIR="${FINGUARD_PACK_DIR:-}"
COMPOSE_FILE=""

if [ -n "$SCRIPT_DIR" ] && find_compose_file "$SCRIPT_DIR" >/dev/null; then
  PACK_DIR="$SCRIPT_DIR"
  COMPOSE_FILE="$(find_compose_file "$SCRIPT_DIR")"
elif [ -n "${FINGUARD_PACK_DIR:-}" ] && find_compose_file "$FINGUARD_PACK_DIR" >/dev/null; then
  PACK_DIR="$FINGUARD_PACK_DIR"
  COMPOSE_FILE="$(find_compose_file "$FINGUARD_PACK_DIR")"
elif find_compose_file "$PACK_DIR_DEFAULT" >/dev/null; then
  PACK_DIR="$PACK_DIR_DEFAULT"
  COMPOSE_FILE="$(find_compose_file "$PACK_DIR_DEFAULT")"
else
  need_cmd git
  PACK_DIR="${FINGUARD_PACK_DIR:-$PACK_DIR_DEFAULT}"
  info "cloning https://github.com/${REPO}.git into ${PACK_DIR}"
  if [ -d "$PACK_DIR/.git" ]; then
    git -C "$PACK_DIR" fetch --depth 1 origin
    git -C "$PACK_DIR" checkout -q FETCH_HEAD 2>/dev/null || git -C "$PACK_DIR" pull --ff-only
  else
    mkdir -p "$(dirname "$PACK_DIR")"
    git clone --depth 1 "https://github.com/${REPO}.git" "$PACK_DIR"
  fi
  COMPOSE_FILE="$(find_compose_file "$PACK_DIR")" || die "cloned ${REPO} but distribution/compose/docker-compose.yml is missing"
fi

PRODUCT_IMAGE="${FINGUARD_IMAGE:-${IMAGE_NS}/finguard:${VERSION}}"
MOCK_IMAGE="${FINGUARD_MOCK_ERP_IMAGE:-${IMAGE_NS}/finguard-mock-erp:${VERSION}}"
export FINGUARD_IMAGE="$PRODUCT_IMAGE"
export FINGUARD_MOCK_ERP_IMAGE="$MOCK_IMAGE"

compose_lab() {
  compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT" --profile greenfield "$@"
}

if [ "$ACTION" = "down" ]; then
  info "stopping lab project ${COMPOSE_PROJECT}"
  compose_lab down --volumes --remove-orphans
  info "stopped"
  exit 0
fi

cat >&2 <<EOF
FinGuard lab (unsigned image, no SBOM).
  pack:     ${PACK_DIR}
  product:  ${PRODUCT_IMAGE}
  mock-erp: ${MOCK_IMAGE}
This is not a production IdP or customer ERP proof.
EOF

if [ "$SKIP_PULL" != "1" ]; then
  info "pulling images"
  compose_lab pull
fi

info "starting greenfield profile"
compose_lab up -d --wait --wait-timeout 180

info "waiting for gateway /healthz"
ready=0
i=0
while [ "$i" -lt 40 ]; do
  if curl -fsS -m 2 http://127.0.0.1:13000/healthz >/dev/null 2>&1; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 1
done
[ "$ready" = "1" ] || die "agentgateway /healthz not ready on :13000 (try: docker compose -p ${COMPOSE_PROJECT} logs)"

need_cmd python3
key="try-$(date +%s)-$$"
info "exactly-once write through :13000/writes"
compose_lab exec -T finguard curl -fsS -m 5 -X POST http://mock-erp:18080/writes/reset >/dev/null
curl -fsS -m 5 -X POST http://127.0.0.1:13000/writes \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${key}" \
  -d "{\"batch\":\"allow\",\"run\":\"${key}\"}" \
  | python3 -c 'import json,sys; n=json.load(sys.stdin)["write_number"]; assert n>=1, n'
curl -fsS -m 5 -X POST http://127.0.0.1:13000/writes \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${key}" \
  -d "{\"batch\":\"allow\",\"run\":\"${key}\"}" >/dev/null
writes="$(compose_lab exec -T finguard curl -fsS -m 5 http://mock-erp:18080/writes)"
echo "$writes" | python3 -c 'import json,sys; n=json.load(sys.stdin)["writes"]; assert n==1, n; print("OK: erp writes="+str(n)+" (replay held exactly-once)")'

cat <<EOF

Lab is up.

  Gateway (agents point here):  http://127.0.0.1:13000
  FinGuard HTTP:                http://127.0.0.1:19191
  Mock ERP (lab only):          http://127.0.0.1:18080
  Admin token:                  local-compose-token

Next (journal, fail-closed, Action Manifest):
  $( [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lab-exercises.sh" ] && echo "$SCRIPT_DIR/lab-exercises.sh" || echo "sh ${PACK_DIR}/lab-exercises.sh" )
  docs/lab.md · 中文: docs/lab.zh.md

Stop:
  $( [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/try.sh" ] && echo "$SCRIPT_DIR/try.sh --down" || echo "FINGUARD_PACK_DIR=${PACK_DIR} sh ${PACK_DIR}/try.sh --down" )

Cluster install (your Postgres + IdP): docs/install-cluster.md
  中文: docs/install-cluster.zh.md
EOF
