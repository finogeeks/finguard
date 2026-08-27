# FinGuard customer deploy: first protected service

For **customer IT** or a **FinClip system engineer** on-site. Same procedure either way.

Companion (Chinese): [customer-deploy.zh.md](customer-deploy.zh.md)  
Customer IAM / IdP (OIDC JWT + JWKS): [identity-iam.md](identity-iam.md) · [中文](identity-iam.zh.md)  
Vault / credential custody: [vault-custody.md](vault-custody.md) · [中文](vault-custody.zh.md)  
Local engineering drills: [runbook.md](runbook.md) (not this document)  
Topology *why*: [product-spec.md](product-spec.md) §7.2 / §7.3

**Status:** pilot / design-partner pack. Pin `image.digest` after a signed release
and verify with [supply-chain.md](supply-chain.md). Do not claim
product-spec §24.0 GA go, 信创 directory listing, or 密评 certification.

---

## 1. What you receive vs what you provide

You receive **one image** (`ghcr.io/finogeeks/finguard` — `finguard` + pinned `agentgateway`) plus Compose and Helm. Postgres and Vault are **not** in that image.

Laptop lab (mock ERP, not customer proof):

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

From this tree: `docs/public-finguard/try.sh`. Public pack (docs, skills, Helm): `finogeeks/finguard`.

| You provide | Why |
| --- | --- |
| Postgres 16+ (HA as required) | Store of record: ledger, journal, hash-chained audit |
| Admin token secret | Bearer for `/v1/*` admin APIs |
| IdP JWKS (issuer + audience + JWKS URL) | Caller identity. Lab JWKS is rehearsal only. In-house IAM (not Keycloak/Zitadel): same JWT contract or a thin broker — [identity-iam.md](identity-iam.md) §3 |
| TLS cert for the hostname you will front | Reverse-proxy topology terminates TLS **legitimately** — no MITM CA |
| One legacy **write** API | First onboarding target: method, path, auth, timeout/retry |
| Optional: existing Envoy / APISIX / Kong | Lowest-friction path if security will not approve a new inline proxy |
| Optional: Vault / OpenBao | Credential custody so agents never see the ERP secret. How-to: [vault-custody.md](vault-custody.md) |

You do **not** need FinSAFE, FinClaw, or ChatKit for day 1.

Optional vendor rehearsal (not customer proof): `./try.sh` then `./lab-exercises.sh`. That proves the laptop mock stack. It does **not** prove the customer IdP or ERP.

---

## 2. Choose topology

| Situation | Topology | Helm |
| --- | --- | --- |
| High-value first service; you may put a proxy in front of it | **Greenfield / service-fronting** (§7.2): agentgateway fronts the service; FinGuard on loopback in the same pod | `agentgateway.enabled=true` (default) |
| Security already approved an edge (Envoy-family, APISIX, Kong) | **Existing-gateway** (§7.3): their edge keeps TLS and routing; FinGuard is an application they call | `agentgateway.enabled=false` |

Do **not** use transparent forward-proxy + CA distribution as the day-1 bank story (product-spec §7.1).

Existing-gateway call shapes:

- Envoy-family: `ext_authz` + `ext_proc` on FinGuard gRPC (`:19090` in the chart). `failureMode: deny` / `failClosed`.
- Non-Envoy: `POST /v1/decide` with `{"method","path","body"}` and the caller JWT. Reference: `distribution/configs/existing-gateway.yaml`.

Sidecar (greenfield) talks to FinGuard on **loopback** — gRPC TLS may be off. Off-loopback (existing-gateway, or gateway in another pod) **must** set TLS.

---

## 3. Deploy

Pull the product image (pin a digest after a signed release):

```bash
docker pull ghcr.io/finogeeks/finguard:0.1.0
```

Laptop lab / local tag: `./scripts/prod/build-ghcr-images.sh` then `FINGUARD_SKIP_PULL=1 docs/public-finguard/try.sh`.

Create secrets **before** `helm install` if TLS is on (chart default `tls.enabled=true` expects `tls.secretName`):

```bash
kubectl create secret generic finguard-admin --from-literal=token='…'
kubectl create secret generic finguard-postgres --from-literal=url='postgres://…'
# off-loopback only:
kubectl create secret tls finguard-grpc-tls --cert=tls.crt --key=tls.key
```

Render, then install. Point `agentgateway.backendHost` at the **real** service, not a mock.

```bash
helm template finguard distribution/helm/finguard \
  --set image.repository=ghcr.io/finogeeks/finguard \
  --set image.tag=0.1.0 \
  --set replicaCount=2 \
  --set oidc.issuer='https://idp.example.com' \
  --set oidc.audience=finguard \
  --set oidc.jwksUrl='https://idp.example.com/jwks.json' \
  --set adminTokenExistingSecret=finguard-admin \
  --set postgres.urlExistingSecret=finguard-postgres \
  --set agentgateway.enabled=true \
  --set agentgateway.backendHost='erp.example.svc:80' \
  --set agentgateway.pathPrefix=/writes \
  --set tls.enabled=false
# greenfield same-pod: tls.enabled=false is acceptable.
# existing-gateway / off-loopback: tls.enabled=true and create tls.secretName.
# IAM / IdP strings: docs/identity-iam.md (iss/aud must match the live token).
```

Existing-gateway:

```bash
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

Then wire the customer edge to FinGuard gRPC (or `POST /v1/decide`).

**Compose dry-run** (lab iron, mock ERP — do not leave `mock-erp` in production):

```bash
docker compose -f distribution/compose/docker-compose.yml --profile greenfield up --build
# FinGuard-only (existing-gateway analogue):
docker compose -f distribution/compose/docker-compose.yml --profile control-plane up --build
./scripts/tests/distribution-image-smoke.sh
```

Chart gaps to apply with an overlay / extra env if needed (not templated today):

- Vault custody: overlay env (`FINGUARD_VAULT_ADDR`, `FINGUARD_VAULT_TOKEN`, `FINGUARD_VAULT_SECRET_PATH`, `FINGUARD_SECRET_BACKEND`, `FINGUARD_INJECT_HEADER`). Chart does not template these. Procedure: [vault-custody.md](vault-custody.md)
- RSA PEM instead of JWKS: `FINGUARD_OIDC_RSA_PEM` (still requires `FINGUARD_OIDC_ISSUER`)
- HS256 is **local-verifiable only** — not a production IdP

---

## 4. Validate the deployment

Do this **before** pointing real agents at the front door. Prefer a **source checkout** for `finguard doctor` (it checks `distribution/` files). In-cluster, the same binary will FAIL workspace pin/Helm/config path checks — use the HTTP probes below.

From a checkout, with the same env the process runs:

```bash
export FINGUARD_POSTGRES_URL='postgres://…'
export FINGUARD_OIDC_ISSUER='https://idp.example.com'
export FINGUARD_OIDC_JWKS_URL='https://idp.example.com/jwks.json'
finguard doctor --config config/finguard.example.yaml
```

Expect: `postgres_store: ok`, `mcp_replay: gated_off`, `caller_identity: oidc jwks issuer=…` (still tagged `production IdP proof=inbox` until a live partner IdP is signed off), `independence: ok`. `oidc hs256` or `stub` is **not** a customer pass.

HTTP bind in Helm is `:8088` (Compose local is `:19191`). Replace host/port.

| # | Check | Pass |
| --- | --- | --- |
| 1 | Unauthenticated admin | `GET /v1/journal` without Bearer → **401** |
| 2 | Authenticated metrics | `GET /metrics` with `Authorization: Bearer <admin>` succeeds |
| 3 | Fail-closed | Stop/scale FinGuard to 0. A mutating call through the gateway must **not** reach the legacy service |
| 4 | Exactly-once | Same `Idempotency-Key` twice on the write path; upstream write count stays **1** |
| 5 | Audit | `finguard audit verify --postgres-url "$FINGUARD_POSTGRES_URL"` and/or `GET /v1/journal` with admin Bearer |
| 6 | Identity | JWT with wrong `iss` / `aud` / expired → **401**. Valid `obo_user` JWT (`sub` = human, `act.sub` = agent) journals the human in `act_sub`, not a god service-account `sub` |

Wrong issuer example:

```bash
curl -s -o /tmp/oidc-iss.json -w '%{http_code}' \
  -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
  -H "x-finguard-id-token: $WRONG_ISS_JWT" \
  -d '{"action_id":"erp.write","manifest_version":"1","parameters":{}}' \
  "http://${HTTP}/v1/actions/invoke"
# expect 401
```

MCP: native ExtMcp synthesized replay stays **gated off**. If agents speak MCP-over-HTTP, use the OpenAPI → governed HTTP workaround (`distribution/configs/mcp-openapi-http.yaml`). Do not silently enable `FINGUARD_MCP_REPLAY=patched` on a customer cluster.

---

## 5. Protect the first legacy service

Pick **one expensive write** (pay, transfer, booking) — not a read-only search.

1. **Cut DNS or base URL** so agents hit the FinGuard front (or the existing-gateway route that calls FinGuard). Agents never receive the raw ERP URL or secret.
2. **Route** that path prefix to the real backend. Keep `failureMode: deny` / `failClosed`.
3. **Onboard under dual control** (the manifest path must match the live write).
   Open `/console` with the System administrator JWT (`token_zhang`), complete the
   Catalog wizard, attach the change ticket, and submit. A distinct Security
   administrator opens the review inbox with `token_li` and accepts. The wizard accepts
   secret references only, never secret values.

   Automation uses the same two-principal workflow. `onboarding.json` contains the
   wizard's spec (topology, route, manifest, scoped grant, and any `secret_ref`):

```bash
id="$(
  curl -fsS -H "Authorization: Bearer $token_zhang" \
    -H 'content-type: application/json' \
    --data @onboarding.json \
    "http://${HTTP}/v1/onboardings" | jq -r .id
)"

curl -fsS -H "Authorization: Bearer $token_zhang" \
  -H 'content-type: application/json' \
  -d '{"change_ticket_id":"CHG-1234"}' \
  "http://${HTTP}/v1/onboardings/${id}/submit"

curl -fsS -H "Authorization: Bearer $token_li" \
  -H 'content-type: application/json' \
  -d '{}' \
  "http://${HTTP}/v1/onboardings/${id}/accept"
```

Direct valid `POST /v1/action-manifests` is not a live-registration shortcut; it returns
`403` with `{"reason":"use_onboardings"}`. Until manifested, unknown endpoints can run
`allow_with_reliability`. Promote this write off that baseline as soon as the shape is
known. SOAP/WSDL and JSON-RPC use the same onboarding loop with `protocol.kind` set
accordingly.

4. **Identity:** agent calls carry a JWT FinGuard can verify (`iss` / `aud` / JWKS) as `Authorization: Bearer` on the data plane (`x-finguard-id-token` still accepted). For `obo_user`, `sub` is the human and `act.sub` is the agent. Customer IdP procedure: [identity-iam.md](identity-iam.md).
5. **Custody (Tier 2):** inject the ERP credential on allow from Vault; agents never see it. Procedure: [vault-custody.md](vault-custody.md). Env-var inject is not a customer pass.
6. **Cutover drill:** one duplicate retry with the same `Idempotency-Key`, one FinGuard restart mid-flight, `audit verify` green, upstream write count = 1. Then open the route to the first agent runtime you do **not** control.

Further services are the same loop, not a new product.

---

## 6. What not to claim

- Lab PASS (`./try.sh` / `./lab-exercises.sh`) = production IdP or design-partner ERP
- Compose Vault / experimental RustyVault = 信创 or 密评 evidence
- `FINGUARD_MCP_REPLAY=patched` = GA MCP replay (upstream ExtMcp §7.4.5 still inbox)
- Floating `:0.1.0` without a digest pin = signed supply chain
- This procedure = product-spec §24.0 GA go (partner ERP, production IdP, customer-peak soak remain)

Day-1 success: **one legacy write API, agents redirected, doctor/HTTP probes green, fail-closed proven, exactly-once proven, audit chain intact.**
