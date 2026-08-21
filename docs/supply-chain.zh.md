# 校验已签名的 FinGuard 镜像（SBOM）

English: [supply-chain.md](supply-chain.md)

审计链只和写出它的二进制一样可信。公开包发布工作流会 **按 digest 签名**
`ghcr.io/finogeeks/finguard:<version>`，并 **附带 SPDX SBOM 证明**。该流水线
出现之前的实验标签是未签名的——旧标签上 `cosign verify` 失败是预期行为。

公钥在本仓库：[`cosign.pub`](../cosign.pub)。

当前已签名的 `0.1.0` digest（2026-08-21）：

`sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5`

此 digest 之前的同名标签未签名。更新说明：[CHANGELOG.zh.md](../CHANGELOG.zh.md)。不要宣称 GA。

## 校验（客户 / 现场工程师）

```bash
IMG=ghcr.io/finogeeks/finguard@sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5

curl -fsSL -o cosign.pub \
  https://raw.githubusercontent.com/finogeeks/finguard/main/cosign.pub

cosign verify --key cosign.pub "$IMG"
cosign verify-attestation --key cosign.pub --type spdxjson "$IMG"
```

Helm 设置 `image.digest` 时，`finguard doctor` 会打印 `FINGUARD_IMAGE_DIGEST`，
以及镜像内 `agentgateway` 二进制的 sha256。

## 这不能证明什么

- 已进信创目录或已获密评
- 集群实际跑的就是该 digest（请钉 `image.digest`，不要漂 `:latest`）
- 触发工作流的操作员身份——只证明 digest 与已发布公钥匹配

Mock-ERP 镜像是实验夹具，**不签名**。
