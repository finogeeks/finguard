# FinGuard Helm 图表

English: [README.md](README.md)

**一次安装拉起产品：** FinGuard + 钉死的 agentgateway（一个镜像），以及 Postgres（默认由本图表启动，可关掉）。

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.0 \
  --set image.digest=sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5 \
  --set agentgateway.backendHost='erp.example.svc:80'
```

用你们自己的库：`--set postgres.bundled=false --set postgres.urlExistingSecret=…`。
已有网关：`--set agentgateway.enabled=false`（非回环需要 TLS）。

本图表可用 digest 钉死已签名镜像。当前 `0.1.0` 钉死：

`image.digest=sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5`

`values.yaml` 默认仍按 tag，给本机实验用。校验：
https://github.com/finogeeks/finguard/blob/main/docs/supply-chain.zh.md
默认镜像是 `ghcr.io/finogeeks/finguard`（`linux/amd64` 与 `linux/arm64`）。本机实验：https://github.com/finogeeks/finguard（仓库根目录 `try.sh`）。

线上 OIDC：`oidc.issuer`、`oidc.audience`、`oidc.jwksUrl`。JWKS 为空即桩身份，不是客户验收通过。自建 IAM 用同一组三个值（或 RSA PEM / 签发层）—— 没有厂商插件。GA go 仍为否。步骤：
[接入 IAM](../../../docs/identity-iam.zh.md)
（英文：[identity-iam.md](../../../docs/identity-iam.md)）。

Vault / OpenBao 托管用环境变量叠加（`FINGUARD_VAULT_ADDR`、token、path、`FINGUARD_INJECT_HEADER`）。图表不模板化。步骤：
[接入 Vault](../../../docs/vault-custody.zh.md)
（英文：[vault-custody.md](../../../docs/vault-custody.md)）。

客户步骤：[客户部署说明](../../../docs/customer-deploy.zh.md)
（英文：[customer-deploy.md](../../../docs/customer-deploy.md)）。
