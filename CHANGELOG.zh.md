# 更新日志

`finogeeks/finguard` 面向公开用户的说明。不要宣称 GA、信创或密评。

英文：[CHANGELOG.md](CHANGELOG.md)

## [Unreleased]

- 运维控制台说明：`docs/operator-console.zh.md`。在 HTTP 绑定打开 `/console`
  （本机 `:19191`，Helm `:8088`）。视图需要带 `admin_role` 的调用方 JWT。
  `try.sh` 桩身份返回 403 是预期。本树中的页面不再发送 `x-finguard-admin-role`。
  已签名的 `0.1.0` digest 仍是旧字段文案；把 JWT 贴进令牌框即可。

## [0.1.0] - 2026-08-21

已签名产品镜像（校验见 [supply-chain.zh.md](docs/supply-chain.zh.md)）：

`ghcr.io/finogeeks/finguard@sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5`

Helm 钉死：

```bash
--set image.tag=0.1.0 \
--set image.digest=sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5
```

此 digest **之前** 发布的同名 `0.1.0` 标签未签名。Mock-ERP 不签名。

### 新增

- 本机实验：`try.sh` 拉取 `ghcr.io/finogeeks/finguard` 与
  `ghcr.io/finogeeks/finguard-mock-erp`，启动 Compose 绿地，经
  `:13000/writes` 检查恰好一次重放。
- Helm 图表默认 `ghcr.io/finogeeks/finguard`。
- 运维技能 `finguard-try` 与 `finguard-customer-deploy`（中英）。
- 客户 IAM / IdP 说明：`docs/identity-iam.zh.md`（OIDC JWT + JWKS；中英）。
  自建 IAM（不是 Keycloak/Zitadel）走同一契约或薄签发层。
- Vault / 凭证托管说明：`docs/vault-custody.zh.md`（KV 注入；Helm 叠加；中英）。
- GHCR 镜像为 `linux/amd64` 与 `linux/arm64`。
- Helm 一键：默认启动 Postgres（`postgres.bundled=false` 可改用已有库）。
- 中文文档索引与本机集成实验手册（`docs/lab.zh.md`、`lab-exercises.sh`）。

### 变更（本次签名切流）

- 产品镜像 Cosign 签名 + SPDX SBOM 证明。按 `docs/supply-chain.zh.md` 校验。
- 调用方 JWT 的 `env` 声明：连接器或清单标明环境（如 `production`）时必须匹配；
  缺省视为 `environment_mismatch`。OIDC 开启时忽略伪造的
  `x-finguard-environment`。
- 管理员 `admin_role`（系统 / 安全 / 审计）只取已校验 JWT。忽略伪造的
  `x-finguard-admin-role`。熔断声明 / 列表 / 解除需要安全岗。
- 代办仍要求 JWT `act.sub`；OIDC 开启时忽略伪造的 `x-finguard-acted-as`。
