# Changelog

Public-facing notes for `finogeeks/finguard`. Unsigned images; no SBOM.

## [Unreleased]

## [0.1.0] - 2026-08-17

### Added

- Laptop lab: `try.sh` pulls `ghcr.io/geeksfino/finguard` and
  `ghcr.io/geeksfino/finguard-mock-erp`, starts Compose greenfield, checks
  exactly-once replay through `:13000/writes`.
- Helm chart defaults to `ghcr.io/geeksfino/finguard`.
- Operator skills `finguard-try` and `finguard-customer-deploy` (EN/zh).
