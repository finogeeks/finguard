# Install FinGuard on a cluster

中文：[install-cluster.zh.md](install-cluster.zh.md)

**One Helm command starts the product:** FinGuard, agentgateway, and Postgres.
You do not install those three yourself. Same image as `try.sh`.

**Status:** unsigned image, no SBOM. Pin `image.tag`.

You need a Kubernetes cluster, Helm, and the hostname of **one real write API**
(ERP/CRM). Point agents at the FinGuard Service on port 13000 — not at that API.

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.0 \
  --set agentgateway.backendHost='erp.example.svc:80'
```

That is the whole install for a first cluster trial. The chart creates an admin
token and starts Postgres inside the release.

```bash
kubectl get secret finguard-admin -o jsonpath='{.data.token}' | base64 -d; echo
```

## Later (optional)

These are not required to get it running:

| When | What |
| --- | --- |
| You already run Postgres | `--set postgres.bundled=false --set postgres.urlExistingSecret=…` (Secret key `url`) |
| Company login (IdP) | `--set oidc.issuer=… --set oidc.audience=… --set oidc.jwksUrl=…` — stub identity is not a customer pass. In-house IAM: same three values (or RSA PEM / a broker), not a vendor plugin. Procedure: [identity-iam.md](identity-iam.md) |
| Vault / OpenBao custody | Overlay env (`FINGUARD_VAULT_ADDR`, token, path, `FINGUARD_INJECT_HEADER`). Chart does not template Vault. Procedure: [vault-custody.md](vault-custody.md) |
| You already have Envoy / APISIX / Kong | `--set agentgateway.enabled=false` and TLS on the FinGuard gRPC port |
| Off-loopback TLS | `--set tls.enabled=true` and create `tls.secretName` **before** install |

Do not point `agentgateway.backendHost` at mock ERP.

## Check it

1. `GET /v1/journal` without Bearer → **401**
2. `GET /metrics` with the admin token succeeds
3. Scale FinGuard to 0; a write through the gateway must **not** reach the backend
4. Same `Idempotency-Key` twice → upstream write count stays **1**

Company IAM / OIDC JWKS: [identity-iam.md](identity-iam.md).
Vault / custody: [vault-custody.md](vault-custody.md).
First protected write: [customer-deploy.md](customer-deploy.md).
