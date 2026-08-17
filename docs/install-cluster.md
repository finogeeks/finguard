# Install FinGuard on a cluster

中文：[install-cluster.zh.md](install-cluster.zh.md)

Same product image as `try.sh`, installed with Helm. You provide Postgres and
identity. The chart does not run a database.

**Status:** unsigned image, no SBOM. Pin `image.tag` (prefer a digest once you have one).

## What you provide

| You provide | Why |
| --- | --- |
| Postgres 16+ | Ledger, journal, hash-chained audit |
| Admin token Secret | Bearer for `/v1/*` |
| IdP issuer + audience + JWKS URL | Caller identity. Lab tokens are not this |
| TLS for the hostname you front | Reverse-proxy terminates TLS legitimately |
| One legacy **write** API | First onboarding target |

You do not need FinSAFE, FinClaw, or ChatKit on day 1.

## Topology

| Situation | Helm |
| --- | --- |
| You may put a proxy in front of the service | `agentgateway.enabled=true` (default). Same-pod sidecar; `tls.enabled=false` is acceptable |
| Existing Envoy / APISIX / Kong stays | `agentgateway.enabled=false`. Off-loopback **must** use TLS |

Do not use transparent forward-proxy + enterprise CA distribution as the day-1 path.

## Install

```bash
kubectl create secret generic finguard-admin --from-literal=token='…'
kubectl create secret generic finguard-postgres --from-literal=url='postgres://…'
# off-loopback only:
kubectl create secret tls finguard-grpc-tls --cert=tls.crt --key=tls.key
```

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
```

Point `agentgateway.backendHost` at the **real** service, not mock ERP.

Existing-gateway:

```bash
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

Then `helm upgrade --install` with the same values. Chart default `tls.enabled=true`
expects `tls.secretName` to exist **before** install.

## Validate

In-cluster, use HTTP probes (workspace `finguard doctor` pin checks need a source
checkout you do not have from this public pack):

1. `GET /v1/journal` without Bearer → **401**
2. `GET /metrics` with admin Bearer succeeds
3. Scale FinGuard to 0; a mutating call through the gateway must **not** reach the backend
4. Same `Idempotency-Key` twice → upstream write count stays **1**
5. Wrong `iss` / `aud` / expired JWT → **401**

`oidc hs256` or stub identity is **not** a customer pass.

Next: [customer-deploy.md](customer-deploy.md).
