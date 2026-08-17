---
name: finguard-customer-deploy
description: >
  从 GHCR + Helm 在客户集群部署 FinGuard：拓扑、Secret、helm template、HTTP
  探测、第一条存量写、Action Manifest。超出本机实验、切流第一条 ERP/SOAP/REST
  写、或回答客户该如何部署时使用。
---

# FinGuard 客户部署（公开包）

人跟
https://github.com/finogeeks/finguard/blob/main/docs/customer-deploy.zh.md
（英文：`docs/customer-deploy.md`）。本技能只编排步骤，不能代替把 markdown 交给客户。

**工作目录：** 公开包根目录（Helm 图表在 `distribution/helm/finguard/`）。

## 硬规则

1. 不要宣称 GA、已签名镜像、SBOM、信创目录或密评。
2. 不要把 `./try.sh` 当作生产 IdP 或设计伙伴 ERP 证明。
3. 不要把 `agentgateway.backendHost` 指到 mock-erp。
4. 除非客户接受并披露 pin 时补丁，否则不要设 `FINGUARD_MCP_REPLAY=patched`。
5. 不要用 HS256 或桩身份作为客户验收通过。生产路径是 issuer + JWKS（或 RSA PEM）。
6. 集群内用 `docs/install-cluster.zh.md` 的 HTTP 矩阵。不要要求私有源码树来跑
   `finguard doctor` 的工作区 pin 检查。

## 流程

```
- [ ] 已选拓扑（绿地 vs 已有网关）
- [ ] 镜像：ghcr.io/finogeeks/finguard:<version>（钉 tag 或 digest）
- [ ] Helm 值：issuer、jwksUrl、Secret
- [ ] 已审查 helm template；tls.enabled 与回环/非回环一致
- [ ] 安装；Pod 就绪
- [ ] HTTP 探测
- [ ] 故障关闭 + 恰好一次
- [ ] 第一条写路径已接入；Action Manifest 已登记
- [ ] 切流演练；智能体已改道
```

### 1. 拓扑

- 允许新加联机代理 → `agentgateway.enabled=true`，`backendHost` = 真实服务，
  `pathPrefix` = 写路径。同 Pod：`tls.enabled=false` 可接受。
- 保留已批准的 Envoy/APISIX/Kong → `agentgateway.enabled=false`。Envoy 族：
  `ext_authz`+`ext_proc` 故障关闭。否则：`POST /v1/decide`。

非回环：`tls.enabled=true` 时安装前必须已有 TLS Secret。

### 2. 部署

跟 `docs/install-cluster.zh.md`。先 `helm template` 再 apply。镜像仓库
`ghcr.io/finogeeks/finguard`。图表不模板化 Vault 注入开关。

### 3. 验收

记录命令输出。故障关闭漏写，或客户 IdP 场景下身份仍是桩/HS256，立刻停。

### 4. 第一条服务

一条昂贵的 **写**。清单 `protocol.path` 必须与线上路径一致。
`obo_user` 需要 JWT `act.sub`。然后重复键 + 重启演练。

## 输出

短部署记录：拓扑、镜像 tag/digest、issuer/JWKS URL（不要密钥）、首个
`action_id`+路径、哪些验收行通过/失败、具名阻塞（IdP、TLS、未签名镜像、MCP 门控）。

操作员在用中文文档时用中文说；标志、JSON 键、路径保持英文。
