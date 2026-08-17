# FinGuard (public pack)

**中文：** [README.zh.md](README.zh.md)

FinGuard is the runtime governance layer between agents and enterprise write APIs
(CRM, ERP, ticketing, internal HTTP). Agents do not get raw enterprise credentials.

This repository is the **public home** for install docs, the laptop lab script, Helm,
and operator skills. It does **not** contain engine source. Images are unsigned and
have no SBOM — do not treat them as a GA supply-chain claim.

## Quick lab (recommended first)

Needs Docker with Compose. Pulls `ghcr.io/geeksfino/finguard` and
`ghcr.io/geeksfino/finguard-mock-erp`. Bundled Postgres + mock ERP. Stub identity.

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

Or from a clone:

```bash
./try.sh
./try.sh --down
```

The lab proves the product process (front door, exactly-once replay). It does **not**
prove your IdP or a real ERP.

## Cluster install

Your Postgres 16+, IdP JWKS, and one real write API. Same product image, Helm chart
in [`distribution/helm/finguard/`](distribution/helm/finguard/):

- [Getting started](docs/getting-started.md) — lab
- [Install on a cluster](docs/install-cluster.md) — Helm
- [First protected service](docs/customer-deploy.md) — cutover

## Operator skills (for AI agents)

- [finguard-try](skills/finguard-try/SKILL.md) — run the laptop lab
- [finguard-customer-deploy](skills/finguard-customer-deploy/SKILL.md) — Helm + first write

## Images

| Image | What |
| --- | --- |
| `ghcr.io/geeksfino/finguard:<version>` | Product: `finguard` + pinned agentgateway |
| `ghcr.io/geeksfino/finguard-mock-erp:<version>` | Lab fixture only |

Public git is [`finogeeks/finguard`](https://github.com/finogeeks/finguard). Images
currently publish under `ghcr.io/geeksfino` (GitHub Actions token). Pin a version.

If the GHCR package is still private, `docker login ghcr.io` once, or set
`FINGUARD_SKIP_PULL=1` after loading images your vendor gave you.
