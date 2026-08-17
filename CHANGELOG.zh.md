# 更新日志

`finogeeks/finguard` 面向公开用户的说明。镜像未签名、无 SBOM。

英文：[CHANGELOG.md](CHANGELOG.md)

## [Unreleased]

- GHCR 镜像为 `linux/amd64` 与 `linux/arm64`。
- Helm 一键：默认启动 Postgres（`postgres.bundled=false` 可改用已有库）。
- 中文文档索引与本机集成实验手册（`docs/lab.zh.md`、`lab-exercises.sh`）。

## [0.1.0] - 2026-08-17

### 新增

- 本机实验：`try.sh` 拉取 `ghcr.io/finogeeks/finguard` 与
  `ghcr.io/finogeeks/finguard-mock-erp`，启动 Compose 绿地，经
  `:13000/writes` 检查恰好一次重放。
- Helm 图表默认 `ghcr.io/finogeeks/finguard`。
- 运维技能 `finguard-try` 与 `finguard-customer-deploy`（中英）。
