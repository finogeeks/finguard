# 保护第一个存量服务

English: [customer-deploy.md](customer-deploy.md)

给客户信息化或现场工程师。先做实验：[getting-started.zh.md](getting-started.zh.md)。
集群安装：[install-cluster.zh.md](install-cluster.zh.md)。

**状态：** 镜像未签名、无 SBOM。不要宣称 GA、已进信创目录或已获密评。

## 拓扑（短）

| 现场 | Helm |
| --- | --- |
| 允许在服务前加代理 | `agentgateway.enabled=true`。同 Pod：`tls.enabled=false` 可接受 |
| 保留已有 Envoy 族 / APISIX / Kong | `agentgateway.enabled=false`。非回环必须 TLS |

Envoy 族打 FinGuard gRPC（`:19090`）的 `ext_authz` + `ext_proc`，
`failureMode: deny` / `failClosed`。其他边缘：`POST /v1/decide`，体为
`{"method","path","body"}`，并带调用方 JWT。

## 智能体接入前验收

Helm HTTP 绑定 `:8088`（Compose 实验是 `:19191`）。

| # | 检查 | 通过 |
| --- | --- | --- |
| 1 | 未认证管理接口 | 无 Bearer 的 `GET /v1/journal` → **401** |
| 2 | 已认证指标 | 带管理 Bearer 的 `GET /metrics` 成功 |
| 3 | 故障关闭 | FinGuard 副本为 0：写请求不得打到后端 |
| 4 | 恰好一次 | 同一 `Idempotency-Key` 两次；上游写入次数仍为 **1** |
| 5 | 身份 | 错误 `iss` / `aud` / 过期 JWT → **401**。`obo_user` 流水记 `act.sub` |

桩身份 / HS256 **不是** 客户验收通过。

## 保护一条昂贵的写

不要选只读查询。切 DNS 或 base URL，让智能体打到 FinGuard（或已有网关的治理路由）。智能体拿不到 ERP 原始 URL 或密钥。

登记清单，`protocol.path` 必须与线上写路径一致：

```bash
curl -fsS -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{
    "schema_version": 1,
    "service": "erp",
    "action_id": "erp.invoice.pay",
    "version": "1",
    "display_name": "Pay invoice",
    "protocol": {"kind": "rest", "method": "POST", "path": "/writes"},
    "risk": {"level": "high", "kind": "w"},
    "approval": {},
    "auth": {"mode": "obo_user"}
  }' \
  "http://${HTTP}/v1/action-manifests"
```

未登记前，未知端点可以走 `allow_with_reliability`。路径形状明确后尽快把这条写提升出基线。

切流演练：同一 `Idempotency-Key` 重试一次、FinGuard 中途重启一次、上游写入次数 = 1。然后把路由开给第一个你们控制不了的智能体运行时。

## 不要宣称

- 本机 `try.sh` 通过 = 生产 IdP 或设计伙伴 ERP
- 未签名的 `ghcr.io/finogeeks/finguard` = 已签名供应链
- 本流程 = GA go
