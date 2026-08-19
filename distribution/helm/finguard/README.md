# FinGuard Helm chart

中文：[README.zh.md](README.zh.md)

**One install starts the product:** FinGuard + pinned agentgateway (one image)
and Postgres (started by this chart unless you turn that off).

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set agentgateway.backendHost='erp.example.svc:80'
```

Use your own database: `--set postgres.bundled=false --set postgres.urlExistingSecret=…`.
Existing gateway: `--set agentgateway.enabled=false` (off-loopback needs TLS).

This chart does **not** ship a signed image or SBOM. Default image is
`ghcr.io/finogeeks/finguard` (`linux/amd64` and `linux/arm64`). Pin `image.tag`.
Laptop lab: https://github.com/finogeeks/finguard (`try.sh`).

Live OIDC: `oidc.issuer`, `oidc.audience`, `oidc.jwksUrl`. Empty JWKS = stub
identity. That is not a customer pass. In-house IAM uses the same three values
(or RSA PEM / a broker) — there is no vendor plugin. GA go stays NO. Procedure:
[`docs/identity-iam.md`](../../../docs/identity-iam.md)
(Chinese: [`docs/identity-iam.zh.md`](../../../docs/identity-iam.zh.md)).

Customer procedure: [`docs/customer-deploy.md`](../../../docs/customer-deploy.md)
(Chinese: [`docs/customer-deploy.zh.md`](../../../docs/customer-deploy.zh.md)).
