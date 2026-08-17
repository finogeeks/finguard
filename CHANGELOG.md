# Changelog

Public-facing notes for `finogeeks/finguard`. Unsigned images; no SBOM.

## [Unreleased]

- GHCR images are `linux/amd64` and `linux/arm64`.
- Chinese docs index, lab workbook (`docs/lab.zh.md`), and `lab-exercises.sh`.

## [0.1.0] - 2026-08-17

### Added

- Laptop lab: `try.sh` pulls `ghcr.io/finogeeks/finguard` and
  `ghcr.io/finogeeks/finguard-mock-erp`, starts Compose greenfield, checks
  exactly-once replay through `:13000/writes`.
- Helm chart defaults to `ghcr.io/finogeeks/finguard`.
- Operator skills `finguard-try` and `finguard-customer-deploy` (EN/zh).
