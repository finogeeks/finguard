# Changelog

Public-facing notes for `finogeeks/finguard`. Do not claim GA, 信创, or 密评.

## [Unreleased]

### Added

- FinGuard request-flow explainer video (v0.2, ~77s, EN VO + burned-in subtitles)
  under [`docs/media/`](docs/media/), linked from the README poster.

## [0.1.3] - 2026-08-27

Signed product image (verify [supply-chain.md](docs/supply-chain.md)):

`ghcr.io/finogeeks/finguard@sha256:46ade9e3e7bd66894905dfefaeae816d5d332b26ae8a8feee09dc958f7613d9c`

Helm pin:

```bash
--set image.tag=0.1.3 \
--set image.digest=sha256:46ade9e3e7bd66894905dfefaeae816d5d332b26ae8a8feee09dc958f7613d9c
```

Mock-ERP is not signed. Do not claim GA.

### Added

- Dual-control onboarding (`/v1/onboardings`) and operator console `/console`.
  Views need a caller JWT with `admin_role`. Stub `try.sh` identity returns 403.
- RFC 8693 inbound claims (`sub` = human, `act.sub` = agent) with gateway-vended
  downstream token exchange (`auth.downstream: gateway_exchange`). FinGuard does
  not mint the downstream token.

### Changed

- Public pack lab pointers use `try.sh` / `lab-exercises.sh` (not private
  `integration-lab`).

## [0.1.0] - 2026-08-21

Signed product image (verify [supply-chain.md](docs/supply-chain.md)):

`ghcr.io/finogeeks/finguard@sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5`

Helm pin:

```bash
--set image.tag=0.1.0 \
--set image.digest=sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5
```

Tags named `0.1.0` published **before** this digest are unsigned. Mock-ERP is
not signed.

### Added

- Laptop lab: `try.sh` pulls `ghcr.io/finogeeks/finguard` and
  `ghcr.io/finogeeks/finguard-mock-erp`, starts Compose greenfield, checks
  exactly-once replay through `:13000/writes`.
- Helm chart defaults to `ghcr.io/finogeeks/finguard`.
- Operator skills `finguard-try` and `finguard-customer-deploy` (EN/zh).
- Customer IAM / IdP guide: `docs/identity-iam.md` (OIDC JWT + JWKS; EN+zh).
  In-house IAM (not Keycloak/Zitadel) uses the same contract or a thin broker.
- Vault / credential custody guide: `docs/vault-custody.md` (KV inject; Helm overlay; EN+zh).
- GHCR images are `linux/amd64` and `linux/arm64`.
- Helm one-shot: chart starts Postgres unless `postgres.bundled=false`.
- Chinese docs index, lab workbook (`docs/lab.zh.md`), and `lab-exercises.sh`.

### Changed (this signed cut)

- Cosign signature + SPDX SBOM attestation on the product image. Verify with
  `docs/supply-chain.md`.
- Caller JWT `env` claim: a connector or manifest that declares an environment
  (for example `production`) requires a matching claim. Omitting it is
  `environment_mismatch`. Spoofed `x-finguard-environment` is ignored when OIDC
  is on.
- Administrator `admin_role` (System / Security / Audit) is taken from the
  verified JWT only. Spoofed `x-finguard-admin-role` is ignored. Halt
  declare/list/lift require Security.
- On-behalf-of still requires JWT `act.sub`; spoofed `x-finguard-acted-as` is
  ignored when OIDC is on.
