# Laptop lab — integration checks

中文：[lab.zh.md](lab.zh.md)

Use this after [`try.sh`](../try.sh) prints `OK: erp writes=1`. The lab is **REST +
mock ERP + stub identity**. It is enough to prove an agent can sit in front of
FinGuard and that writes are journaled and fail-closed. It is **not** a customer
IdP, a real ERP, or SOAP/MCP/A2A coverage.

## 1. Lab must be up

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
# or, from a clone:
./try.sh
```

If `docker pull` returns `denied` / 401, the GHCR packages are still **private**.
That is a maintainer visibility setting, not something you fix in this git repo.
Workaround only if your vendor gave you images: `docker login ghcr.io` or
`FINGUARD_SKIP_PULL=1 ./try.sh`.

Then either copy-paste the curls below or run:

```bash
./lab-exercises.sh
```

| URL | Role |
| --- | --- |
| `http://127.0.0.1:13000` | Agent front door (point agents here, **not** at the ERP) |
| `http://127.0.0.1:19191` | FinGuard admin HTTP |
| `http://127.0.0.1:18080` | Mock ERP (lab only; agents must not use this URL) |

Admin bearer: `local-compose-token`.

## 2. Admin API is gated

```bash
# no token → 401
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19191/v1/journal

# with token → JSON array (journal of the try.sh write)
curl -fsS -H 'Authorization: Bearer local-compose-token' \
  http://127.0.0.1:19191/v1/journal | python3 -m json.tool | head
```

Hash-chain check:

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' \
  -X POST http://127.0.0.1:19191/v1/audit/verify
```

Expect `{"ok":true,...}`.

## 3. Agent-shaped write (integration)

An agent (or `curl` standing in for one) calls the **gateway**, with an
`Idempotency-Key`. It never sees Postgres or the ERP secret.

```bash
KEY="agent-$(date +%s)"
curl -fsS -X POST http://127.0.0.1:13000/writes \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${KEY}" \
  -d "{\"batch\":\"allow\",\"run\":\"${KEY}\"}"

# mock ERP mutation count (lab inspection only)
curl -fsS http://127.0.0.1:18080/writes
```

Replay the same key: the JSON `writes` count must **not** increase.

Point an HTTP agent runtime at `http://127.0.0.1:13000` as the enterprise base
URL, path `/writes`. Do not configure the agent with `http://127.0.0.1:18080`.

## 4. Fail-closed

If FinGuard is down, mutating calls through the gateway must not reach the mock
ERP (`failureMode: deny` / `failClosed`).

```bash
./lab-exercises.sh
# includes: stop FinGuard → POST /writes fails → start FinGuard → healthz
```

Manual: `docker compose -p finguard-try --profile greenfield stop finguard`, then
POST `:13000/writes` (must not be HTTP 200 with a new ERP write). Start the
container again before you continue.

## 5. Register a lab Action Manifest

Unknown paths can still `allow_with_reliability`. Registering a manifest is how
you name the write your agent will call:

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' \
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
  http://127.0.0.1:19191/v1/action-manifests
```

## 6. What this lab does not prove

| You saw | You did **not** prove |
| --- | --- |
| Stub caller identity | Your IdP JWKS / RS256 / token exchange |
| No Vault in `try.sh` | Credential custody against your Vault/OpenBao — [vault-custody.md](vault-custody.md) |
| Mock ERP `/writes` | A real CRM/ERP, SOAP, MCP, or A2A backend |
| Unsigned `ghcr.io/finogeeks/finguard` | Signed supply chain / SBOM / GA |

Cluster path (your Postgres + IdP + real write API):
[install-cluster.md](install-cluster.md), [identity-iam.md](identity-iam.md),
[vault-custody.md](vault-custody.md), then [customer-deploy.md](customer-deploy.md).

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `denied` / 401 pulling GHCR | Package visibility is still private. Login, or skip-pull vendor images |
| `bind: address already in use` on `13000` / `19191` / `18080` | Stop the other process, or `./try.sh --down` and retry |
| Apple Silicon / linux/arm64 | Images ship `linux/amd64` and `linux/arm64`. Docker picks the native one |
| `missing required command: python3` | Install Python 3; `try.sh` uses it to assert write counts |
| Piped `curl \| sh` wants git | The one-liner clones into `~/.finguard-try`; install `git` or clone this repo and run `./try.sh` |

Stop: `./try.sh --down`.
