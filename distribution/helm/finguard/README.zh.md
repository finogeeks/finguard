# FinGuard Helm 图表

English: [README.md](README.md)

独立行动网关的最小参考图表。**一个产品镜像**（`finguard` + 钉死的 `agentgateway` 二进制）。Postgres 和 Vault 留在图表外 —— 把 `postgres.urlExistingSecret` 指到你们已有的数据库。

绿地：`agentgateway.enabled=true`（默认）在同一 Pod 启动 agentgateway 边车（回环访问 FinGuard）。已有网关：设 `agentgateway.enabled=false`，保留客户的 Envoy/APISIX/Kong。

```bash
helm template finguard distribution/helm/finguard
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

本图表 **不** 附带已签名镜像或 SBOM。默认镜像是 `ghcr.io/finogeeks/finguard`。钉死 `image.tag`（有 digest 后优先钉 digest）。非回环：打开 `tls.enabled`，并在安装 **之前** 创建 `tls.secretName`（默认 `tls.enabled=true` 要求该 Secret 已存在）。同 Pod 绿地边车可以设 `tls.enabled=false`。本机实验：`docs/public-finguard/try.sh`（或公开的 `finogeeks/finguard` 包装）。

线上 OIDC：`oidc.issuer`、`oidc.audience`、`oidc.jwksUrl`（写入 `FINGUARD_OIDC_JWKS_URL`）。RSA PEM / HS256 仍需用环境变量 overlay。生产 IdP 证明仍为 inbox。GA go 仍为否。

客户 / 现场工程师步骤：[客户部署说明](../../../docs/customer-deploy.zh.md)
（英文：[customer-deploy.md](../../../docs/customer-deploy.md)）。
