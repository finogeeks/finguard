# FinGuard Helm chart

中文：[README.zh.md](README.zh.md)

**One install starts the product:** FinGuard + pinned agentgateway (one image)
and Postgres (started by this chart unless you turn that off).

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.3 \
  --set image.digest=sha256:46ade9e3e7bd66894905dfefaeae816d5d332b26ae8a8feee09dc958f7613d9c \
  --set agentgateway.backendHost='erp.example.svc:80'
```

Use your own database: `--set postgres.bundled=false --set postgres.urlExistingSecret=…`.
Existing gateway: `--set agentgateway.enabled=false` (off-loopback needs TLS).

This chart can pin a **signed** image by digest. Current `0.1.3` pin:

`image.digest=sha256:46ade9e3e7bd66894905dfefaeae816d5d332b26ae8a8feee09dc958f7613d9c`

Default `values.yaml` is still tag-only for the laptop lab. Verify:
https://github.com/finogeeks/finguard/blob/main/docs/supply-chain.md
Default image is `ghcr.io/finogeeks/finguard` (`linux/amd64` and `linux/arm64`).
Laptop lab: https://github.com/finogeeks/finguard (`try.sh`).

Live OIDC: `oidc.issuer`, `oidc.audience`, `oidc.jwksUrl`. Empty JWKS = stub
identity. That is not a customer pass. In-house IAM uses the same three values
(or RSA PEM / a broker) — there is no vendor plugin. GA go stays NO. Procedure:
[`docs/identity-iam.md`](../../../docs/identity-iam.md)
(Chinese: [`docs/identity-iam.zh.md`](../../../docs/identity-iam.zh.md)).

Operator console: `GET /console` on the HTTP port. Paste a caller JWT with
`admin_role`. Procedure: [`docs/operator-console.md`](../../../docs/operator-console.md)
(Chinese: [`docs/operator-console.zh.md`](../../../docs/operator-console.zh.md)).

Vault / OpenBao custody is an env overlay (`FINGUARD_VAULT_ADDR`, token, path,
`FINGUARD_INJECT_HEADER`). The chart does not template it. Procedure:
[`docs/vault-custody.md`](../../../docs/vault-custody.md)
(Chinese: [`docs/vault-custody.zh.md`](../../../docs/vault-custody.zh.md)).

Customer procedure: [`docs/customer-deploy.md`](../../../docs/customer-deploy.md)
(Chinese: [`docs/customer-deploy.zh.md`](../../../docs/customer-deploy.zh.md)).
