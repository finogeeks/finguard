# FinGuard 客户部署：保护第一个存量服务

给 **客户信息化 / 基础设施** 或 **现场系统工程师**。两套角色走同一套步骤。

英文对照：[customer-deploy.md](customer-deploy.md)  
客户 IAM / IdP（OIDC JWT + JWKS）：[identity-iam.zh.md](identity-iam.zh.md) · [English](identity-iam.md)  
Vault / 凭证托管：[vault-custody.zh.md](vault-custody.zh.md) · [English](vault-custody.md)  
中文落地页：[README.zh.md](../README.zh.md)  
本地研发演练：[runbook.md](runbook.md)（不是本文）  
拓扑原理：[product-spec.md](product-spec.md) §7.2 / §7.3

**状态：** 试点 / 设计伙伴包。签名发布后钉 `image.digest`，并按
[supply-chain.md](supply-chain.md) 校验。不要宣称产品规格 §24.0 GA、已进信创目录、或已获密评证书。

---

## 1. 交付物 vs 客户准备

交付 **一个镜像**（`ghcr.io/finogeeks/finguard` — `finguard` + 钉死的 `agentgateway`）以及 Compose / Helm。Postgres 和密管 **不在** 该镜像里。

本机实验（mock ERP，不是客户验收）：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

本仓库：`docs/public-finguard/try.sh`。公开包装（文档、技能、Helm）：`finogeeks/finguard`。

| 客户准备 | 用途 |
| --- | --- |
| Postgres 16+（按需高可用） | 账本、流水、可核验审计链的权威存储 |
| 管理令牌 Secret | `/v1/*` 管理接口的 Bearer |
| 身份提供方 JWKS（issuer + audience + JWKS URL） | 调用方身份。实验室 JWKS 只作彩排。自建 IAM（不是 Keycloak/Zitadel）：同一套 JWT 契约或薄签发层 — [identity-iam.zh.md](identity-iam.zh.md) 第 3 节 |
| 将要对外暴露的主机名 TLS 证书 | 反向代理是 **合法终止 TLS**，不是中间人 CA |
| 一条存量 **写** 接口 | 首个接入对象：方法、路径、鉴权、超时/重试 |
| 可选：已有 Envoy / APISIX / Kong | 安全不允许新加联机代理时的最低摩擦入口 |
| 可选：Vault / OpenBao | 凭证托管，智能体拿不到 ERP 密钥。步骤：[vault-custody.zh.md](vault-custody.zh.md) |

第一天 **不需要** FinSAFE、FinClaw、ChatKit。

可选厂内彩排（不是客户验收）：`./try.sh` 然后 `./lab-exercises.sh`。只证明本机 mock 栈，**不能** 证明客户 IdP 或 ERP。

---

## 2. 选择拓扑

| 现场情况 | 拓扑 | Helm |
| --- | --- | --- |
| 高价值首个服务，允许在其前面加代理 | **绿地 / 服务前置**（§7.2）：agentgateway 挡在服务前；FinGuard 同 Pod 回环 | `agentgateway.enabled=true`（默认） |
| 安全已批准现有边缘（Envoy 族、APISIX、Kong） | **已有网关**（§7.3）：边缘继续终止 TLS 和路由；FinGuard 作为被调用的应用 | `agentgateway.enabled=false` |

不要把透明正向代理 + 向全行下发 CA 当作银行第一天方案（产品规格 §7.1）。

已有网关的调用形态：

- Envoy 族：FinGuard gRPC（图表中 `:19090`）上的 `ext_authz` + `ext_proc`。`failureMode: deny` / `failClosed`。
- 非 Envoy：`POST /v1/decide`，体为 `{"method","path","body"}`，并带调用方 JWT。参考：`distribution/configs/existing-gateway.yaml`。

绿地边车走 **回环** —— gRPC TLS 可以关。跨 Pod / 已有网关 **必须** 开 TLS。

---

## 3. 部署

拉取未签名产品镜像（或导入客户仓库并钉 digest）：

```bash
docker pull ghcr.io/finogeeks/finguard:0.1.3
```

本机实验 / 本地标签：`./scripts/prod/build-ghcr-images.sh`，然后 `FINGUARD_SKIP_PULL=1 docs/public-finguard/try.sh`。

若 TLS 开启，**先** 建 Secret（图表默认 `tls.enabled=true`，需要 `tls.secretName`）：

```bash
kubectl create secret generic finguard-admin --from-literal=token='…'
kubectl create secret generic finguard-postgres --from-literal=url='postgres://…'
# 仅非回环：
kubectl create secret tls finguard-grpc-tls --cert=tls.crt --key=tls.key
```

先 `helm template` 再安装。`agentgateway.backendHost` 指向 **真实** 服务，不要指向 mock。

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
# 绿地同 Pod：tls.enabled=false 可以。
# 已有网关 / 非回环：tls.enabled=true 并创建 tls.secretName。
# IAM / IdP 字符串：docs/identity-iam.zh.md（iss/aud 必须与真实令牌一致）。
```

已有网关：

```bash
helm template finguard distribution/helm/finguard --set agentgateway.enabled=false
```

再把客户边缘接到 FinGuard gRPC（或 `POST /v1/decide`）。

**Compose 干跑**（实验室机器、mock ERP —— 生产不要留 `mock-erp`）：

```bash
docker compose -f distribution/compose/docker-compose.yml --profile greenfield up --build
# 仅 FinGuard（对应已有网关）：
docker compose -f distribution/compose/docker-compose.yml --profile control-plane up --build
./scripts/tests/distribution-image-smoke.sh
```

图表尚未模板化、需要 overlay / 额外环境变量的项：

- 密管托管：叠加环境变量（`FINGUARD_VAULT_ADDR`、`FINGUARD_VAULT_TOKEN`、`FINGUARD_VAULT_SECRET_PATH`、`FINGUARD_SECRET_BACKEND`、`FINGUARD_INJECT_HEADER`）。图表不模板化这些。步骤：[vault-custody.zh.md](vault-custody.zh.md)
- 不用 JWKS、改用 RSA PEM：`FINGUARD_OIDC_RSA_PEM`（仍要 `FINGUARD_OIDC_ISSUER`）
- HS256 **只适合本地可验证** —— 不是生产 IdP

---

## 4. 验收部署

在把真实智能体指到前门 **之前** 做完。`finguard doctor` 会检查 `distribution/` 文件，适合在 **源码检出** 上跑。集群内同一二进制会对工作区 pin/Helm/配置路径报 FAIL —— 改用下面的 HTTP 探测。

在检出目录、使用与进程相同的环境：

```bash
export FINGUARD_POSTGRES_URL='postgres://…'
export FINGUARD_OIDC_ISSUER='https://idp.example.com'
export FINGUARD_OIDC_JWKS_URL='https://idp.example.com/jwks.json'
finguard doctor --config config/finguard.example.yaml
```

期望：`postgres_store: ok`、`mcp_replay: gated_off`、`caller_identity: oidc jwks issuer=…`（在正式伙伴 IdP 签字前仍会带 `production IdP proof=inbox`）、`independence: ok`。`oidc hs256` 或 `stub` **不算** 客户验收通过。

Helm HTTP 端口是 `:8088`（Compose 本地是 `:19191`）。按现场改 host/port。

| # | 检查 | 通过标准 |
| --- | --- | --- |
| 1 | 未认证管理面 | 不带 Bearer 的 `GET /v1/journal` → **401** |
| 2 | 带令牌的指标 | `Authorization: Bearer <admin>` 访问 `GET /metrics` 成功 |
| 3 | 故障关闭 | 把 FinGuard 停到 0。经网关的写请求 **不得** 打到存量系统 |
| 4 | 恰好一次 | 同一 `Idempotency-Key` 写两次；上游写入计数仍为 **1** |
| 5 | 审计 | `finguard audit verify --postgres-url "$FINGUARD_POSTGRES_URL"` 和/或带管理 Bearer 的 `GET /v1/journal` |
| 6 | 身份 | 错误 `iss` / `aud` / 过期 JWT → **401**。合法 `obo_user` JWT（`sub` = 自然人，`act.sub` = 智能体）流水把人记在 `act_sub`，而不是万能服务账号 `sub` |

错误 issuer 示例：

```bash
curl -s -o /tmp/oidc-iss.json -w '%{http_code}' \
  -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
  -H "x-finguard-id-token: $WRONG_ISS_JWT" \
  -d '{"action_id":"erp.write","manifest_version":"1","parameters":{}}' \
  "http://${HTTP}/v1/actions/invoke"
# 期望 401
```

MCP：原生 ExtMcp 合成回放默认 **关闭**。若智能体走 MCP-over-HTTP，用 OpenAPI → 受治理 HTTP 的变通（`distribution/configs/mcp-openapi-http.yaml`）。不要在客户集群上悄悄打开 `FINGUARD_MCP_REPLAY=patched`。

---

## 5. 保护第一个存量服务

选 **一条代价高的写**（支付、转账、下单），不要选只读查询。

1. **改 DNS 或 base URL**，让智能体打到 FinGuard 前门（或会回调 FinGuard 的已有网关路由）。智能体永远拿不到裸 ERP 地址或密钥。
2. **把该路径前缀** 指到真实后端。保持 `failureMode: deny` / `failClosed`。
3. **双人控制登记**（路径必须与线上写接口一致）。System 管理员打开 `/console`，用
   `token_zhang` 走 Catalog 向导、附变更单号并提交。另一位 Security 管理员用
   `token_li` 在收件箱接受。向导只接受密钥 **引用**，不要填密钥值。

   自动化走同一套双人接口。`onboarding.json` 含向导 spec（拓扑、路由、清单、授权和
   可选 `secret_ref`）：

```bash
id="$(
  curl -fsS -H "Authorization: Bearer $token_zhang" \
    -H 'content-type: application/json' \
    --data @onboarding.json \
    "http://${HTTP}/v1/onboardings" | jq -r .id
)"

curl -fsS -H "Authorization: Bearer $token_zhang" \
  -H 'content-type: application/json' \
  -d '{"change_ticket_id":"CHG-1234"}' \
  "http://${HTTP}/v1/onboardings/${id}/submit"

curl -fsS -H "Authorization: Bearer $token_li" \
  -H 'content-type: application/json' \
  -d '{}' \
  "http://${HTTP}/v1/onboardings/${id}/accept"
```

直接对有效 body 做 `POST /v1/action-manifests` 不是上线捷径；返回 `403`，
`{"reason":"use_onboardings"}`。未登记的端点可以走 `allow_with_reliability`。形状一旦明确，立刻把这条写操作升为受治理。SOAP/WSDL、JSON-RPC 同一套循环，改 `protocol.kind` 即可。

4. **身份：** 智能体请求携带 FinGuard 能校验的 JWT（`iss` / `aud` / JWKS），数据面上用 `Authorization: Bearer`（`x-finguard-id-token` 仍然接受）。`obo_user` 时 `sub` 是自然人、`act.sub` 是智能体。客户 IdP 步骤：[identity-iam.zh.md](identity-iam.zh.md)。
5. **托管（第二档）：** 放行时从 Vault 注入 ERP 凭证；智能体看不见。步骤：[vault-custody.zh.md](vault-custody.zh.md)。环境变量注入不算客户验收通过。
6. **切流演练：** 同一 `Idempotency-Key` 重试一次、FinGuard 中途重启一次、`audit verify` 通过、上游写入 = 1。然后对 **不受我们控制** 的第一个智能体运行时开放路由。

后续服务重复本循环，不是新产品。

---

## 6. 禁止对外口径

- 实验室 PASS（`./try.sh` / `./lab-exercises.sh`）= 生产 IdP 或设计伙伴 ERP
- Compose Vault / 实验性 RustyVault = 信创或密评证据
- `FINGUARD_MCP_REPLAY=patched` = GA 级 MCP 回放（上游 ExtMcp §7.4.5 仍在 inbox）
- 未签名的 `ghcr.io/finogeeks/finguard` / `finguard:0.1.0` = 已签名供应链
- 走完本文 = 产品规格 §24.0 GA（伙伴 ERP、生产 IdP、客户峰值浸泡仍未关闭）

第一天成功标准：**一条存量写接口、智能体已改道、doctor/HTTP 探测通过、故障关闭已证、恰好一次已证、审计链完整。**
