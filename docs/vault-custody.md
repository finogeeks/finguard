# Connect FinGuard to Vault (credential custody)

中文：[vault-custody.zh.md](vault-custody.zh.md)

FinGuard can **inject an enterprise credential on allow** so agents never hold
the ERP/CRM secret. The secret lives in your Vault-compatible KV (or, for a
lab, a process env var). FinGuard does not replace HashiCorp Vault, OpenBao,
or your 密管, and it does not ship a Vault server in the product image.

There is **no vendor Vault plugin**. HashiCorp, OpenBao, and experimental
RustyVault work because they speak a KV HTTP API FinGuard already calls.

**Status:** signed `0.1.0` image — pin digest and verify
[supply-chain.md](supply-chain.md). Do not claim GA. The laptop lab (`try.sh`)
does **not** start Vault and does not prove custody.

Related: [install-cluster.md](install-cluster.md), [customer-deploy.md](customer-deploy.md),
[identity-iam.md](identity-iam.md).

---

## 1. What custody is (and is not)

On an allowed write, FinGuard adds a header (for example `x-erp-token`) whose
value it read from the secret source. The agent request does not carry that
secret. Direct calls to the backend without the header must fail.

| Mode | When | Customer pass? |
| --- | --- | --- |
| Vault / OpenBao KV (`FINGUARD_VAULT_ADDR` + token) | Production custody | Yes, when the backend rejects missing credentials |
| `--inject-from-env` / `FINGUARD_INJECT_FROM_ENV` | Laptop / bootstrap | **No** — snapshot of an env var, not a Vault |
| No inject header and no Vault | Lab default (`try.sh`) | **No** — agents or the mock ERP may still “work” |

`FINGUARD_ADMIN_TOKEN` is the FinGuard HTTP admin Bearer. It is **not** the ERP
secret. Do not mix them.

---

## 2. What your Vault must serve

FinGuard uses the Vault HTTP API from the pod:

1. `GET {addr}/v1/sys/health` with `X-Vault-Token` — **required at `serve` start**.
   Unreachable Vault → process exits.
2. `GET {addr}/v1/{secret_path}` — KV read on each inject. HashiCorp/OpenBao KV
   v2 path is typically `secret/data/<name>`.

The JSON body must expose the inject key under `/data/data/<key>` (KV v2) or
`/data/<key>`. Default key name is `token` (`FINGUARD_INJECT_SECRET_KEY`).

If a later KV read fails, FinGuard **omits** the header and logs a warning. It
does not by itself turn the write into a deny. The backend **must** reject
requests that lack the credential.

**Not a customer pass:** Compose dev Vault with root token, RustyVault as 信创
or 密评, env-var inject, empty Vault addr.

---

## 3. Configure FinGuard

The Helm chart does **not** template Vault flags. Overlay env (and, if you
prefer CLI, the same flags on `serve`).

| Env | Flag | Role |
| --- | --- | --- |
| `FINGUARD_VAULT_ADDR` | `--vault-addr` | Base URL, no trailing slash required |
| `FINGUARD_VAULT_TOKEN` | `--vault-token` | Token with read on the KV path. Not the admin token |
| `FINGUARD_VAULT_SECRET_PATH` | `--vault-secret-path` | Default `secret/data/erp` |
| `FINGUARD_SECRET_BACKEND` | `--secret-backend` | `hashicorp` (default), `openbao`, or `rustyvault` |
| `FINGUARD_INJECT_SECRET_KEY` | `--inject-secret-key` | Key inside the secret JSON (default `token`) |
| `FINGUARD_INJECT_HEADER` | `--inject-header` | Header name added on allow (e.g. `x-erp-token`) |

Example Secret + overlay after Helm install:

```bash
kubectl create secret generic finguard-vault \
  --from-literal=FINGUARD_VAULT_TOKEN='s.…'

kubectl set env deploy/finguard \
  FINGUARD_SECRET_BACKEND=hashicorp \
  FINGUARD_VAULT_ADDR='https://vault.example.svc:8200' \
  FINGUARD_VAULT_SECRET_PATH='secret/data/erp' \
  FINGUARD_INJECT_SECRET_KEY=token \
  FINGUARD_INJECT_HEADER=x-erp-token

kubectl set env deploy/finguard --from=secret/finguard-vault
```

The FinGuard pod must be able to **GET** `FINGUARD_VAULT_ADDR` (egress, DNS,
TLS trust). Restart the pod after overlay. `finguard doctor` then reports
`secret_source: vault/hashicorp` (or `vault/openbao`).

Seed KV (HashiCorp/OpenBao; path shapes vary by mount):

```bash
vault kv put secret/erp token='the-erp-credential-agents-must-not-see'
```

Pin `FINGUARD_VAULT_SECRET_PATH` to the API path FinGuard GETs (`secret/data/erp`
on KV v2), not only the `vault kv` CLI name.

OpenBao uses the same client. Set `FINGUARD_SECRET_BACKEND=openbao` and point
`FINGUARD_VAULT_ADDR` at the OpenBao listener.

RustyVault is **experimental** (no official image, often `secret/erp` not
`secret/data/erp`). It is **not 信创** or 密评 evidence.

---

## 4. Validate before agents

1. Backend without the inject header → **401** (or equivalent). If the ERP
   accepts unauthenticated writes, custody does not hold.
2. Write through FinGuard (greenfield `:13000` or existing edge) **without**
   sending the ERP secret → success, and the backend sees the inject header.
3. Wrong or missing Vault token at start → `serve` / pod crash loop (`vault health`).
4. Doctor (source checkout): `secret_source` is `vault/hashicorp` or
   `vault/openbao`, not `env`, when Vault env is set.

Stub identity and custody are independent. Wire the IdP too:
[identity-iam.md](identity-iam.md).

---

## 5. What not to claim

- Laptop `try.sh` PASS = Vault custody is proven
- Overlaying Vault env = GA, **not 信创**, not 密评
- Compose Vault or experimental RustyVault = 密评 or 信创 directory listing
- Floating `:0.1.0` without a digest pin = signed supply chain
- Env-var inject (`FINGUARD_INJECT_FROM_ENV`) = a customer Vault pass
