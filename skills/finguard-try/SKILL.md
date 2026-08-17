---
name: finguard-try
description: >
  Bring up the FinGuard laptop lab from GHCR with try.sh (Compose: product image,
  mock ERP, bundled Postgres). Use when the user wants a 5-minute install, to
  verify exactly-once writes, or to see FinGuard running without a source checkout.
---

# FinGuard laptop lab

**Working directory:** public pack root (`finogeeks/finguard` clone, or
`docs/public-finguard/` inside the private tree).

## Hard rules

1. This lab is mock ERP + stub identity + unsigned image. Do not call it production
   IdP proof, design-partner ERP proof, GA, 信创, or 密评.
2. Do not `docker build` from engine source. Pull (or skip-pull) GHCR tags.
3. Do not point a customer cluster at mock ERP.
4. Do not enable `FINGUARD_MCP_REPLAY=patched` unless the user accepted a pin-time
   patch and it is disclosed.

## Run

Need Docker Compose, `curl`, `python3`. One-liner after the public repo exists:

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

From a pack checkout:

```bash
chmod +x ./try.sh
./try.sh
```

Images already loaded (no GHCR pull):

```bash
FINGUARD_SKIP_PULL=1 ./try.sh
```

Pass if the script prints `OK: erp writes=1 (replay held exactly-once)` and lists
`:13000` / `:19191` / `:18080`.

Admin bearer: `local-compose-token`.

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' http://127.0.0.1:19191/metrics | head
```

Stop: `./try.sh --down`.

## If pull fails

GHCR packages start private. `docker login ghcr.io`, or load vendor-provided images
and set `FINGUARD_SKIP_PULL=1`. Apple Silicon without an arm64 tag uses amd64 via
emulation — slower, still valid for the lab.

## Next

Real Postgres + IdP + real write path: skill `finguard-customer-deploy` and
https://github.com/finogeeks/finguard/blob/main/docs/install-cluster.md
