# FinGuard Helm chart

中文：[README.zh.md](README.zh.md)

Minimal reference chart for the standalone action gateway. **One product image**
(`finguard` + pinned `agentgateway` binaries). Postgres and Vault stay outside
the chart — point `postgres.urlExistingSecret` at a database you already run.

Greenfield: `agentgateway.enabled=true` (default) starts an agentgateway sidecar
in the same pod (loopback to FinGuard). Existing-gateway: set
`agentgateway.enabled=false` and keep the customer's Envoy/APISIX.

```bash
helm template finguard distribution/helm/finguard
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

This chart does **not** ship a signed image or SBOM. Default image is
`ghcr.io/geeksfino/finguard`. Pin `image.tag` (prefer a digest). Off-loopback: set
`tls.enabled` and create `tls.secretName` **before** install (default
`tls.enabled=true` expects that secret). Same-pod greenfield sidecar may set
`tls.enabled=false`. Laptop lab: `docs/public-finguard/try.sh`.

Live OIDC: `oidc.issuer`, `oidc.audience`, and `oidc.jwksUrl` (sets
`FINGUARD_OIDC_JWKS_URL`). RSA PEM / HS256 remain env-only overlays. Production
IdP proof stays inbox. GA go stays NO.

Customer / SE procedure: [`docs/customer-deploy.md`](../../../docs/customer-deploy.md)
(Chinese: [`docs/customer-deploy.zh.md`](../../../docs/customer-deploy.zh.md)).
