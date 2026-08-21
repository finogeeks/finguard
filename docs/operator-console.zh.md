# 运维控制台

English: [operator-console.md](operator-console.md)

FinGuard 在与 `/v1/journal` 相同的 HTTP 绑定上提供 **网页控制台**。它是现有
API（目录、会话、熔断、密钥、告警）的渲染层。不是第二套存储，不是登录产品，
打开页面也不等于 GA。

不要因为打开了这个页面就宣称 GA、信创或密评。

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
| `system` | 总览、目录 |
| `security` | 总览、控制（熔断声明 / 列表 / 解除）、密钥（仅元数据） |
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
