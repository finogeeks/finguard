# Getting started — laptop lab

中文：[getting-started.zh.md](getting-started.zh.md)

Bring FinGuard up on a workstation in a few minutes. **One command** starts the
product stack: FinGuard + pinned agentgateway + Postgres. Mock ERP and stub
identity are lab-only. Unsigned image.

## 1. Prerequisites

- Docker Engine with the Compose v2 plugin (`docker compose version`)
- `curl`, `python3`, and (for the one-liner) `git`
- Ability to pull from `ghcr.io` (or images already loaded locally)

## 2. Run

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

From a clone of this repository:

```bash
./try.sh
```

Pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh -s -- --version 0.1.0
```

Use images you already built or loaded:

```bash
FINGUARD_SKIP_PULL=1 ./try.sh
```

The script pulls `ghcr.io/finogeeks/finguard:<version>` and
`ghcr.io/finogeeks/finguard-mock-erp:<version>`, starts the greenfield profile
(FinGuard + agentgateway + Postgres + mock ERP), then sends one write through
`:13000/writes` twice with the same `Idempotency-Key` and checks the mock ERP
saw **one** mutation.

## 3. What you should see

| URL | Role |
| --- | --- |
| `http://127.0.0.1:13000` | Agent front door (agentgateway) |
| `http://127.0.0.1:19191` | FinGuard HTTP (`/metrics`, `/v1/*`) |
| `http://127.0.0.1:18080` | Mock ERP (lab only) |

Admin bearer for lab HTTP: `local-compose-token`.

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' http://127.0.0.1:19191/metrics | head
```

## 4. Stop

```bash
./try.sh --down
```

## 5. Integration checks

After the lab is up, run journal / fail-closed / Action Manifest checks:

```bash
./lab-exercises.sh
```

Workbook: [lab.md](lab.md) (中文：[lab.zh.md](lab.zh.md)). Point an HTTP agent at
`http://127.0.0.1:13000`, not at the mock ERP.

## 6. Next

Pointing a real agent at a real write API is the cluster path:
[install-cluster.md](install-cluster.md), then your IdP ([identity-iam.md](identity-iam.md)),
optional Vault custody ([vault-custody.md](vault-custody.md)),
then [customer-deploy.md](customer-deploy.md).

Do not keep the mock ERP in a customer cluster. Do not treat this lab as IdP proof.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `denied` pulling `ghcr.io/finogeeks/finguard` | GHCR package is still private. `docker login`, or `FINGUARD_SKIP_PULL=1` with loaded images |
| Port `13000` / `19191` / `18080` in use | Stop the other listener, or `./try.sh --down` |
| Apple Silicon / linux/arm64 | Images ship `linux/amd64` and `linux/arm64`. Docker picks the native one |
