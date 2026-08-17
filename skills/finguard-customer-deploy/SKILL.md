---
name: finguard-customer-deploy
description: >
  Deploy FinGuard on a customer cluster from GHCR + Helm: topology, secrets,
  helm template, HTTP probes, first legacy write, Action Manifest. Use when
  installing beyond the laptop lab, cutting over a first ERP/SOAP/REST write,
  or answering how a customer should deploy FinGuard.
---

# FinGuard customer deploy (public pack)

Humans follow https://github.com/finogeeks/finguard/blob/main/docs/customer-deploy.md
(Chinese: `docs/customer-deploy.zh.md`). This skill orchestrates that procedure.
It is not a substitute for handing the customer the markdown.

**Working directory:** public pack root (Helm chart at `distribution/helm/finguard/`).

## Hard rules

1. Do not claim GA, signed images, SBOM, 信创 directory, or 密评.
2. Do not treat `./try.sh` as production IdP or design-partner ERP proof.
3. Do not point `agentgateway.backendHost` at mock-erp.
4. Do not set `FINGUARD_MCP_REPLAY=patched` unless the customer accepted the
   pin-time patch and it is disclosed.
5. Do not use HS256 or stub identity as a customer pass. Production path is
   issuer + JWKS (or RSA PEM).
6. In-cluster, use the HTTP matrix in `docs/install-cluster.md`. Do not require a
   private source checkout for `finguard doctor` workspace pin checks.

## Workflow

```
- [ ] One-shot Helm: backendHost = real write API (chart starts Postgres + admin token)
- [ ] Image: ghcr.io/finogeeks/finguard:<version> (pin tag or digest)
- [ ] helm upgrade --install; pods ready
- [ ] HTTP probes
- [ ] Fail-closed + exactly-once
- [ ] First write path routed; Action Manifest registered
- [ ] Cutover drill; agents redirected
```

### 1. Topology

- New inline proxy allowed → `agentgateway.enabled=true`, `backendHost` = real
  service, `pathPrefix` = write path. Same-pod: `tls.enabled=false` is acceptable.
- Approved Envoy/APISIX/Kong stays → `agentgateway.enabled=false`. Envoy-family:
  `ext_authz`+`ext_proc` fail-closed. Else: `POST /v1/decide`.

Off-loopback: TLS secret required before install when `tls.enabled=true`.

### 2. Deploy

Follow `docs/install-cluster.md`. Always `helm template` before apply. Image
repository `ghcr.io/finogeeks/finguard`. Chart does not template Vault inject flags.

### 3. Validate

Record command output. Stop if fail-closed leaks writes or identity is stub/HS256
on a customer IdP engagement.

### 4. First service

One expensive **write**. Manifest `protocol.path` must match the live path.
`obo_user` requires JWT `act.sub`. Then duplicate-key + restart drill.

## Output

Short deployment record: topology, image tag/digest, issuer/JWKS URL (no secrets),
first `action_id`+path, which validation rows passed/failed, named blockers
(IdP, TLS, unsigned image, MCP gated).

Speak Chinese if the operator is using the ZH docs; keep flags, JSON keys, and
paths in English.
