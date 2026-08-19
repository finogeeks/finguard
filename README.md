# FinGuard (public pack)

**中文文档：** [README.zh.md](README.zh.md) ·
[文档索引](docs/README.zh.md) ·
[快速开始](docs/getting-started.zh.md) ·
[本机集成实验](docs/lab.zh.md) ·
[集群安装](docs/install-cluster.zh.md) ·
[接入 IAM](docs/identity-iam.zh.md) ·
[接入 Vault](docs/vault-custody.zh.md)

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
./lab-exercises.sh   # 流水、恰好一次、故障关闭（需实验已起来）
```

---

FinGuard is the runtime governance layer between agents and enterprise write APIs
(CRM, ERP, ticketing, internal HTTP). Agents do not get raw enterprise credentials.

This repository is the **public home** for install docs, the laptop lab script, Helm,
and operator skills. It does **not** contain engine source. Images are unsigned and
have no SBOM — do not treat them as a GA supply-chain claim.

## Quick lab (recommended first)

**One command is the product.** `try.sh` starts FinGuard + pinned agentgateway +
Postgres as one Compose stack. You do not install those three yourself. The same
product image holds FinGuard and agentgateway (different entrypoint). Postgres is
the official `postgres:16` image, started for you. Lab-only mock ERP is extra.

Needs Docker with Compose. Pulls `linux/amd64` and `linux/arm64` from GHCR
(Apple Silicon / Graviton use arm64 natively). Stub identity.

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

Or from a clone:

```bash
./try.sh
./lab-exercises.sh
./try.sh --down
```

`try.sh` proves the front door and exactly-once replay. `lab-exercises.sh` then
checks journal gating, an agent-shaped write, fail-closed, and a sample Action
Manifest. Docs: [getting-started.md](docs/getting-started.md), [lab.md](docs/lab.md).

If `docker pull` returns `denied`, the GHCR packages are still private — that is
not fixed by cloning this repo. See [lab.md](docs/lab.md#troubleshooting).

The lab does **not** prove your IdP or a real ERP.

## Cluster install

**One Helm command** starts FinGuard + agentgateway + Postgres. You only pass the
write API hostname. Chart: [`distribution/helm/finguard/`](distribution/helm/finguard/).

- [Docs index](docs/README.md)
- [Getting started](docs/getting-started.md) — lab
- [Laptop integration checks](docs/lab.md) — after `try.sh`
- [Install on a cluster](docs/install-cluster.md) — Helm
- [Connect your IAM](docs/identity-iam.md) — OIDC JWT + JWKS
- [Connect Vault / custody](docs/vault-custody.md) — inject ERP secret on allow
- [First protected service](docs/customer-deploy.md) — cutover

## Operator skills (for AI agents)

- [finguard-try](skills/finguard-try/SKILL.md) — run the laptop lab
- [finguard-customer-deploy](skills/finguard-customer-deploy/SKILL.md) — Helm + first write

## Images

| Image | What |
| --- | --- |
| `ghcr.io/finogeeks/finguard:<version>` | Product: `finguard` + pinned agentgateway (`linux/amd64`, `linux/arm64`) |
| `ghcr.io/finogeeks/finguard-mock-erp:<version>` | Lab fixture only (same platforms) |
| `postgres:16-alpine` | Lab DB via Compose — not in the product image |

Public git is [`finogeeks/finguard`](https://github.com/finogeeks/finguard). Pin a version.
Do not run `:latest` in production. Postgres is **not** in the product image.

If the GHCR package is still private, `docker login ghcr.io` once, or set
`FINGUARD_SKIP_PULL=1` after loading images your vendor gave you.
