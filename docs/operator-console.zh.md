# 运维控制台

English: [operator-console.md](operator-console.md)

FinGuard 在与 `/v1/journal` 相同的 HTTP 绑定上提供 **网页控制台**。它是现有
API（目录、会话、熔断、密钥、告警）的渲染层。不是第二套存储，不是登录产品，
打开页面也不等于 GA。

不要因为打开了这个页面就宣称 GA、信创或密评。

## 上线（onboarding）

目录上线走控制台向导和 `/v1/onboardings/*` 双人审批（System 起草、Security
接受、必须带 `change_ticket_id`）。Security 接受后，**FileSink** 在
`FINGUARD_DATAPLANE_YAML` 已设置时写入 agentgateway yaml（就地 copy，保留
inode），然后执行 `FINGUARD_DATAPLANE_RELOAD_CMD`（Helm：`shareProcessNamespace`
后对 sidecar SIGHUP）。Live 卡片可跑非写探测 `POST /v1/onboardings/{id}/cutover-probes`。
不要把 agentgateway 管理口 `:15000` 当 apply 路径。

`auth.downstream: gateway_exchange` 的编译期拒绝（HTTP 409，body 里的 `reason`）：

| 代码 | 何时 |
| --- | --- |
| `downstream_exchange_unsupported_topology` | `existing_gateway` 拓扑（FinGuard 不拥有那份 yaml） |
| `downstream_exchange_unsupported_protocol` | MCP 协议族 |
| `downstream_exchange_conflict` | 同一条编译路由上的清单在 audience / resource / scope 上不一致 |
| `downstream_exchange_unconfigured` | 未配置 `FINGUARD_OBO_TOKEN_HOST` / `FINGUARD_OBO_CLIENT_ID`（或密钥环境变量不是 `$VAR` 引用） |

这些在 Security 接受时触发，不会在请求时触发。

## 怎么打开

| 场景 | URL |
| --- | --- |
| 本机 `try.sh` | `http://127.0.0.1:19191/console` |
| Helm | Service 端口 **8088** — `kubectl port-forward svc/finguard 8088:8088`，然后打开 `http://127.0.0.1:8088/console` |

```bash
# 页面无需令牌即可加载（只有 HTML）。
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19191/console
# 期望 200
```

Helm 安装后的 NOTES 会打印 HTTP 端口。

## 要粘贴什么

各视图调用 `/v1/catalog`、`/v1/sessions`、`/v1/halts`、`/v1/secrets`、
`/v1/alerts`。这些接口要的是 **调用方 JWT**，payload 里带 `admin_role`：

| `admin_role` | 视图 |
| --- | --- |
| `system` | 总览、目录、Onboard |
| `security` | 总览、控制（熔断声明 / 列表 / 解除）、密钥（仅元数据）、live cutover 探测 |
| `audit` | 会话 |

在你们的 IdP 上签发该声明（与 [identity-iam.zh.md](identity-iam.zh.md) 同一套
RS256 JWT + JWKS）。把 JWT 粘进控制台。 **没有 SSO 登录页**。

API 校验 `admin_role`。旧页面上的角色下拉框不能授权。伪造的
`x-finguard-admin-role` 会被忽略。

**不算客户验收通过：** 桩身份（`try.sh`）、HS256、空 JWKS，或用 Compose 管理令牌
（`local-compose-token`）代替 `admin_role`。本机实验里页面能打开，视图在接上
OIDC 之前返回 **403**。这是预期行为。

OIDC 开启时，控制台把 JWT 放在 `Authorization: Bearer` 和
`x-finguard-id-token`。智能体写操作仍用 [identity-iam.zh.md](identity-iam.zh.md)
的双头（`Authorization` = 管理令牌，`x-finguard-id-token` = 调用方 JWT）。不要混用。

## 这不能证明什么

- 三员角色的设计伙伴走查（§24.0 的 GA 门）
- 设置了 Helm `oidc.*` = 已证明你们的 IdP
- 已签名供应链（请钉 digest；[supply-chain.zh.md](supply-chain.zh.md)）
