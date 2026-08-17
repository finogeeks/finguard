# 在集群上安装 FinGuard

English: [install-cluster.md](install-cluster.md)

与 `try.sh` 同一产品镜像，用 Helm 安装。Postgres 和身份由你们提供。图表不跑数据库。

**状态：** 镜像未签名、无 SBOM。钉死 `image.tag`（有 digest 后优先钉 digest）。

## 你们准备

| 准备 | 用途 |
| --- | --- |
| Postgres 16+ | 账本、流水、可核验审计链 |
| 管理令牌 Secret | `/v1/*` 的 Bearer |
| IdP issuer + audience + JWKS URL | 调用方身份。实验令牌不是这个 |
| 对外主机名的 TLS | 反向代理合法终止 TLS |
| 一条存量 **写** 接口 | 首个接入对象 |

第一天不需要 FinSAFE、FinClaw、ChatKit。

## 拓扑

| 现场 | Helm |
| --- | --- |
| 允许在服务前加代理 | `agentgateway.enabled=true`（默认）。同 Pod 边车；`tls.enabled=false` 可接受 |
| 保留已有 Envoy / APISIX / Kong | `agentgateway.enabled=false`。非回环 **必须** TLS |

不要把透明正向代理 + 全行下发 CA 当作第一天方案。

## 安装

```bash
kubectl create secret generic finguard-admin --from-literal=token='…'
kubectl create secret generic finguard-postgres --from-literal=url='postgres://…'
# 仅非回环：
kubectl create secret tls finguard-grpc-tls --cert=tls.crt --key=tls.key
```

```bash
helm template finguard distribution/helm/finguard \
  --set image.repository=ghcr.io/finogeeks/finguard \
  --set image.tag=0.1.0 \
  --set replicaCount=2 \
  --set oidc.issuer='https://idp.example.com' \
  --set oidc.audience=finguard \
  --set oidc.jwksUrl='https://idp.example.com/jwks.json' \
  --set adminTokenExistingSecret=finguard-admin \
  --set postgres.urlExistingSecret=finguard-postgres \
  --set agentgateway.enabled=true \
  --set agentgateway.backendHost='erp.example.svc:80' \
  --set agentgateway.pathPrefix=/writes \
  --set tls.enabled=false
```

`agentgateway.backendHost` 指向 **真实** 服务，不要指向 mock ERP。

已有网关：

```bash
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

然后用同一组值 `helm upgrade --install`。图表默认 `tls.enabled=true`，安装 **之前** 就要有 `tls.secretName`。

## 验收

集群内用 HTTP 探测（工作区 `finguard doctor` 的 pin 检查需要源码树，本公开包没有）：

1. 无 Bearer 的 `GET /v1/journal` → **401**
2. 带管理 Bearer 的 `GET /metrics` 成功
3. 把 FinGuard 扩到 0；经网关的写请求 **不得** 打到后端
4. 同一 `Idempotency-Key` 两次 → 上游写入次数仍为 **1**
5. 错误 `iss` / `aud` / 过期 JWT → **401**

`oidc hs256` 或桩身份 **不是** 客户验收通过。

下一步：[customer-deploy.zh.md](customer-deploy.zh.md)。
