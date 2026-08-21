# 把 FinGuard 接到你们的 IAM

English: [identity-iam.md](identity-iam.md)

FinGuard 校验你们现有身份提供方（IdP）签发的 **调用方 JWT**。它不替代
Okta、Microsoft Entra ID、Keycloak、Zitadel、Auth0 或本地 IAM，也不提供登录页。

**没有按厂商编写的 IAM 插件。** Keycloak、Zitadel 并不特殊：能接上是因为它们
签发下文的 RS256 JWT + JWKS 契约。自建 IAM、CAS、4A 或区域 IdP 用同一条路径；
目录签不出该契约时，在前面加一层薄 JWT 签发服务。见第 3 节。

**状态：** 已签名 `0.1.0` 镜像 — 钉 digest 并按
[supply-chain.zh.md](supply-chain.zh.md) 校验。不要宣称 GA。本机实验（`try.sh`）用 **桩身份**，
不能证明你们的 IdP。

相关：[install-cluster.zh.md](install-cluster.zh.md)、
[customer-deploy.zh.md](customer-deploy.zh.md)、
[vault-custody.zh.md](vault-custody.zh.md)。

---

## 1. 两种凭证（不要混用）

| 凭证 | 谁持有 | 用途 |
| --- | --- | --- |
| 管理令牌（`FINGUARD_ADMIN_TOKEN`） | 运维 / 调用 FinGuard HTTP 的网关 | `/v1/*` 管理接口的 Bearer（`/v1/journal`、清单、`POST /v1/decide` 等） |
| 来自你们 IAM 的调用方 JWT | 智能体或工作负载 | 谁在操作。按 issuer + JWKS 校验 |

管理令牌 **不是** 公司 SSO。本安装包没有 FinGuard 管理控制台，也没有给人用的
SAML/OIDC 登录界面。

当 FinGuard HTTP 接口两者都要（例如 `POST /v1/actions/invoke` 或
`POST /v1/decide`）时，这样发：

```http
Authorization: Bearer <admin-token>
x-finguard-id-token: <caller-jwt>
```

这些接口上不要把调用方 JWT 放进 `Authorization` —— 那个头是管理令牌。
**绿地数据面**（agentgateway `:13000`）上，智能体在写请求里带
`x-finguard-id-token`；FinGuard 从转发头读取。

---

## 2. 你们的 IAM 必须签发什么

生产路径：**RS256 JWT + JWKS**（FinGuard 够不到 JWKS 时，改用 RSA 公钥 PEM）。

| JWT 字段 | 规则 |
| --- | --- |
| `alg` | `RS256` |
| `iss` | 与 `oidc.issuer` **整串完全一致**（尾斜杠也算） |
| `aud` | 必须包含 `oidc.audience`（Helm 默认：`finguard`） |
| `sub` | 工作负载 / 客户端主体；记为调用方 |
| `exp` | 必填。时钟宽限为 **0** —— 过期即拒 |
| `act.sub` | Action Manifest 为 `auth.mode: obo_user` 时必填（RFC 8693 的 `act` 声明）。这是 **自然人**。只有令牌 `sub` 不够 |
| `env` | 连接器或 Action Manifest 标明环境（如 `production`）时必填。缺省或不匹配是 `environment_mismatch`，不是跳过。OIDC 开启时忽略伪造的 `x-finguard-environment` |
| `admin_role` | 可选。`System` / `Security` / `Audit`（三员）。只取已校验 JWT。忽略伪造的 `x-finguard-admin-role`。熔断声明 / 列表 / 解除需要 `Security` |

JWKS 须是标准 `{"keys":[…]}`，且至少有一把 `kty: RSA`。FinGuard 从 Pod 用
HTTP(S) 拉取。

**不算客户验收通过：** JWKS 为空（桩身份）、HS256 共享密钥 JWT。

### FinGuard 不直接对接的协议

- 作为传输协议的 SAML 2.0、LDAP bind、Kerberos、ADFS WS-Federation
- FinGuard 内部的授权码、设备码或交互式登录
- 用万能服务账号 `sub` 满足 `obo_user`

若目录只有 SAML 或 LDAP，请在前面加一层 OIDC（Entra、Okta、Keycloak、Zitadel
等），再给智能体签发 JWT。这一层可以是你们已有的产品，也可以是第 3 节的薄签发
服务 —— FinGuard 仍然只校验 JWT。

---

## 3. 自建 / 非主流 IAM（不是 Keycloak 或 Zitadel）

不要为每个客户 IdP 给 FinGuard 写适配器。接线第 2 节的 **令牌契约**，或在目录
前面加签发服务。

| 客户现状 | 支持路径 | 不是支持路径 |
| --- | --- | --- |
| 任意签发方已能签发 **RS256 JWT**，且 FinGuard Pod 能 GET 到 JWKS | Helm `oidc.issuer` + `oidc.audience` + `oidc.jwksUrl`，从 **真实令牌** 抄。步骤与 Keycloak 相同。 | 厂商专用连接器、realm 导出、SAML 元数据文件 |
| 有 RS256 JWT，但 Pod 够不到 JWKS（隔离网、分裂 DNS） | 叠加 `FINGUARD_OIDC_RSA_PEM`（IdP **公钥**）。仍要 issuer。 | 用 HS256 共享密钥当客户验收通过 |
| 目录只有 SAML、LDAP、Kerberos、CAS 或 ADFS WS-Federation | 若产品自带 OIDC 就打开（CAS 6+、不少 4A），**或** 跑一层薄 JWT 签发。FinGuard 仍只校验 JWT。 | 让 FinGuard 去做 LDAP bind 或消费 SAML 断言 |
| 边缘已校验 mTLS 并转发 Envoy `x-forwarded-client-cert`，没有 JWT 计划 | 叠加 `FINGUARD_MTLS_TRUST_XFCC=true`。工作负载高保证。`obo_user` 仍要 JWT 的 `act.sub`。 | OIDC 场景用 XFCC 代替 JWKS；可伪造的 `x-finguard-acted-as` |
| 签不出 RS256，也不加签发层 | **阻塞。** 记下来。不要用桩身份上生产。 | 空 JWKS / 桩身份 / HS256 当生产身份 |

### 薄签发服务（客户或集成商范围）

目录签不出第 2 节 JWT 时，在 FinGuard **外面** 跑一个小签发方：

1. 用客户已有协议对智能体做认证。
2. 签发短时 RS256 JWT：`iss`、`aud`（Helm `oidc.audience`，或他们已有的 API
   标识）、`sub`（工作负载）、`exp`；清单为 `obo_user` 时带 `act.sub`。
3. 发布标准 JWKS `{"keys":[…]}` 且含 `kty: RSA`，**或** 把 RSA 公钥 PEM 交给
   运维挂载。
4. 智能体把该 JWT 放在 `x-finguard-id-token`。

签发服务不是 FinGuard 的 crate、Helm 子图表或已认证 IdP。从它 **实际签发的令牌**
抄 `iss` —— 尾斜杠也算。

---

## 4. 配置 FinGuard（Helm）

设置 issuer、audience、JWKS。`jwksUrl` 为空即保持桩身份。

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.0 \
  --set image.digest=sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5 \
  --set agentgateway.backendHost='erp.example.svc:80' \
  --set oidc.issuer='https://idp.example.com/realms/prod' \
  --set oidc.audience=finguard \
  --set oidc.jwksUrl='https://idp.example.com/realms/prod/protocol/openid-connect/certs'
```

与环境变量对应（Compose / 叠加）：

| Helm | 环境变量 |
| --- | --- |
| `oidc.issuer` | `FINGUARD_OIDC_ISSUER` |
| `oidc.audience` | `FINGUARD_OIDC_AUDIENCE`（默认 `finguard`） |
| `oidc.jwksUrl` | `FINGUARD_OIDC_JWKS_URL` |

FinGuard Pod 必须能 **GET** `jwksUrl`（出站 / 防火墙 / TLS 信任）。若不能，
不用 JWKS，改叠加 RSA PEM：

- 仍要 `FINGUARD_OIDC_ISSUER`
- `FINGUARD_OIDC_RSA_PEM` = IdP RSA **公钥** PEM 的路径

图表目前不模板化该 PEM 路径 —— 用额外环境变量 / 挂载的 Secret 加上。

可选：若边缘已校验 mTLS 并转发 Envoy 的 `x-forwarded-client-cert`，叠加
`FINGUARD_MTLS_TRUST_XFCC=true`。OIDC 场景下这 **不能** 代替接线 JWKS。

---

## 5. 配置你们的 IdP

与具体厂商无关的清单：

1. 建一个 **API / 资源**（或授权服务器），其 audience 会出现在智能体令牌上。二选一：
   - 签发 `aud=finguard`（与 Helm 默认一致），或
   - 把 `oidc.audience` 设成你们 IAM 已有的 audience（客户端 ID 或 API 标识）。
2. 为智能体运行时建 **机密客户端**（或工作负载身份），允许它申请该 API。
3. 发布 JWKS。确认集群里的 FinGuard 能拉到。
4. 从 **真实令牌** 的 `iss` 声明抄 issuer 字符串 —— 不要猜。发现文档
   （`/.well-known/openid-configuration`）里的 `issuer` 必须与声明完全一致。
5. 对 `obo_user` 写操作，在令牌上发出 RFC 8693 的
   `act: { "sub": "<human id>" }`。若 IdP 没有 `act` 声明，用令牌定制
   （自定义声明、令牌交换，或 FinGuard 前的薄代理）映射。OIDC 开启时 FinGuard
   **忽略** `x-finguard-acted-as`，所以不能靠自由填写的头来满足代表用户。

常见 issuer / JWKS（替换占位符；以发现文档为准）：

| IdP | 常见 `issuer` | 常见 JWKS |
| --- | --- | --- |
| Microsoft Entra ID | `https://login.microsoftonline.com/<tenant-id>/v2.0` | `https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys` |
| Okta（自定义授权服务器） | `https://<domain>/oauth2/<authServerId>` | `https://<domain>/oauth2/<authServerId>/v1/keys` |
| Keycloak | `https://<host>/realms/<realm>` | `https://<host>/realms/<realm>/protocol/openid-connect/certs` |
| Zitadel | `https://<instance>`（钉死发现文档里的 `issuer`） | `https://<instance>/oauth/v2/keys` |
| Auth0 | `https://<tenant>.auth0.com/` | `https://<tenant>.auth0.com/.well-known/jwks.json` |

以上产品 **不是** 已认证集成。只要它们签发 `iss` / `aud` 与 Helm 一致、且 JWKS
可达的 RS256 JWT，即可接线。钉死你们租户实际签发的字符串。没有名字的自建签发方
用同一组三个 Helm 值 —— 见第 3 节。

---

## 6. 智能体与网关接线

**绿地**（`agentgateway.enabled=true`）：智能体打 FinGuard Service 的 **13000**
端口，不要打 ERP 原地址。每次受治理的写都转发 `x-finguard-id-token`。

**已有 Envoy 族边缘：** `ext_authz` + `ext_proc` 打 FinGuard gRPC（`:19090`），
`failureMode: deny` / `failClosed`。转发调用方 JWT 头，不要剥掉。

**其他边缘：** `POST /v1/decide`，体为 `{"method","path","body"}`，带管理 Bearer
和 `x-finguard-id-token`。

---

## 7. 智能体接入前验收

错误 `iss`、错误 `aud` 或过期 JWT → **401**。清单为 `obo_user` 时，带
`act.sub` 的合法 JWT 必须把自然人记入流水，而不是服务账号 `sub`。

```bash
# 期望 401（错误 issuer）。Helm HTTP 绑定是 :8088。
curl -s -o /tmp/oidc-iss.json -w '%{http_code}' \
  -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
  -H "x-finguard-id-token: $WRONG_ISS_JWT" \
  -H 'content-type: application/json' \
  -d '{"action_id":"erp.invoice.pay","manifest_version":"1","parameters":{}}' \
  "http://${HTTP}/v1/actions/invoke"
```

桩身份 / HS256 **不是** 客户验收通过。完整切流矩阵：
[customer-deploy.zh.md](customer-deploy.zh.md)。

---

## 8. 不要宣称

- 本机 `try.sh` 通过 = 已证明你们的 IdP
- 设置了 Helm `oidc.*` = GA、信创或密评
- 未钉 digest 的漂浮 `:0.1.0` 标签 = 已签名供应链
- 本产品内置了 Keycloak、Zitadel 或其他厂商连接器
