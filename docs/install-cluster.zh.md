# 在集群上安装 FinGuard

English: [install-cluster.md](install-cluster.md)

**一条 Helm 命令拉起产品：** FinGuard、agentgateway、Postgres。这三件不用你自己装。镜像与 `try.sh` 相同。

**状态：** 镜像未签名、无 SBOM。钉死 `image.tag`。

你需要 Kubernetes、Helm，以及 **一条真实写接口**（ERP/CRM）的地址。智能体打 FinGuard Service 的 13000 端口，不要打那条写接口。

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.0 \
  --set agentgateway.backendHost='erp.example.svc:80'
```

这就是集群上第一次试跑的全部安装。图表会创建管理令牌，并在本 release 里启动 Postgres。

```bash
kubectl get secret finguard-admin -o jsonpath='{.data.token}' | base64 -d; echo
```

## 以后（可选）

要跑起来不需要这些：

| 何时 | 做法 |
| --- | --- |
| 已有 Postgres | `--set postgres.bundled=false --set postgres.urlExistingSecret=…`（Secret 的 key 为 `url`） |
| 公司登录（IdP） | `--set oidc.issuer=… --set oidc.audience=… --set oidc.jwksUrl=…` —— 桩身份不是客户验收通过。自建 IAM：同一组三个值（或 RSA PEM / 签发层），不是厂商插件。步骤：[identity-iam.zh.md](identity-iam.zh.md) |
| Vault / OpenBao 托管 | 叠加环境变量（`FINGUARD_VAULT_ADDR`、token、path、`FINGUARD_INJECT_HEADER`）。图表不模板化 Vault。步骤：[vault-custody.zh.md](vault-custody.zh.md) |
| 已有 Envoy / APISIX / Kong | `--set agentgateway.enabled=false`，并给 FinGuard gRPC 开 TLS |
| 非回环 TLS | `--set tls.enabled=true`，安装 **之前** 创建 `tls.secretName` |

不要把 `agentgateway.backendHost` 指到 mock ERP。

## 验收

1. 无 Bearer 的 `GET /v1/journal` → **401**
2. 带管理令牌的 `GET /metrics` 成功
3. 把 FinGuard 扩到 0；经网关的写 **不得** 打到后端
4. 同一 `Idempotency-Key` 两次 → 上游写入次数仍为 **1**

公司 IAM / OIDC JWKS：[identity-iam.zh.md](identity-iam.zh.md)。
Vault / 凭证托管：[vault-custody.zh.md](vault-custody.zh.md)。
保护第一条写：[customer-deploy.zh.md](customer-deploy.zh.md)。
