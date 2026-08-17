# Getting started — laptop lab

中文：[getting-started.zh.md](getting-started.zh.md)

Bring FinGuard up on a workstation in a few minutes. This path uses Docker Compose
and GHCR. It is a **lab**: mock ERP, bundled Postgres, stub caller identity, unsigned
image.

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

The script pulls `ghcr.io/geeksfino/finguard:<version>` and
`ghcr.io/geeksfino/finguard-mock-erp:<version>`, starts the greenfield profile
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

## 5. Next

Pointing a real agent at a real write API is the cluster path:
[install-cluster.md](install-cluster.md) then [customer-deploy.md](customer-deploy.md).

Do not keep the mock ERP in a customer cluster. Do not treat this lab as IdP proof.
