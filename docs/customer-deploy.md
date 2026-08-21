# First protected service

中文：[customer-deploy.zh.md](customer-deploy.zh.md)

For customer IT or an on-site engineer. Lab first: [getting-started.md](getting-started.md)
then [lab.md](lab.md). Cluster install is one Helm command (chart starts Postgres): [install-cluster.md](install-cluster.md).
Company IAM / IdP (OIDC JWT + JWKS): [identity-iam.md](identity-iam.md).
In-house directories use the same JWT contract or a broker, not a vendor plugin.
Vault / custody (inject ERP secret on allow): [vault-custody.md](vault-custody.md).

**Status:** pin digest after a signed release; verify [supply-chain.md](supply-chain.md). Do not claim GA, 信创 directory listing, or 密评.

## Topology (short)

| Situation | Helm |
| --- | --- |
| You may front the service | `agentgateway.enabled=true`. Same-pod: `tls.enabled=false` is acceptable |
| Existing Envoy-family / APISIX / Kong stays | `agentgateway.enabled=false`. Off-loopback must use TLS |

Envoy-family calls FinGuard gRPC (`:19090`) with `ext_authz` + `ext_proc`,
`failureMode: deny` / `failClosed`. Other edges: `POST /v1/decide` with
`{"method","path","body"}`, admin Bearer, and `x-finguard-id-token`. Caller JWT
rules: [identity-iam.md](identity-iam.md).

## Validate before agents

HTTP bind in Helm is `:8088` (Compose lab is `:19191`).

| # | Check | Pass |
| --- | --- | --- |
| 1 | Unauthenticated admin | `GET /v1/journal` without Bearer → **401** |
| 2 | Authenticated metrics | `GET /metrics` with admin Bearer succeeds |
| 3 | Fail-closed | FinGuard at 0 replicas: mutating call must not reach the backend |
| 4 | Exactly-once | Same `Idempotency-Key` twice; upstream write count stays **1** |
| 5 | Identity | Wrong `iss` / `aud` / expired JWT → **401**. `obo_user` journals `act.sub` |

Stub / HS256 identity is not a customer pass. Wire issuer + JWKS before this
row: [identity-iam.md](identity-iam.md).

## Protect one expensive write

Not a read-only search. Cut DNS or base URL so agents hit FinGuard (or the existing
gateway route). Agents never receive the raw ERP URL or secret.

Register a manifest whose `protocol.path` matches the live write:

```bash
curl -fsS -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
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
  "http://${HTTP}/v1/action-manifests"
```

Until manifested, unknown endpoints can run `allow_with_reliability`. Promote this
write off that baseline as soon as the shape is known.

Cutover drill: one duplicate retry with the same `Idempotency-Key`, one FinGuard
restart mid-flight, upstream write count = 1. Then open the route to the first agent
runtime you do not control.

## What not to claim

- Laptop `try.sh` PASS = production IdP or design-partner ERP
- Unsigned `ghcr.io/finogeeks/finguard` = signed supply chain
- This procedure = GA go
