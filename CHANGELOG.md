# Changelog

Public-facing notes for `finogeeks/finguard`. Do not claim GA, 信创, or 密评.

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
