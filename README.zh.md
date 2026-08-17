# FinGuard（公开发行包）

**English:** [README.md](README.md)

FinGuard 是智能体与企业写接口（CRM、ERP、工单、内部 HTTP）之间的运行时治理层。智能体拿不到企业系统的原始凭证。

本仓库是安装文档、本机实验脚本、Helm 与运维技能的 **公开入口**。不含引擎源码。镜像 **未签名、无 SBOM** —— 不要当作 GA 供应链证明。

## 本机实验（建议先做这一步）

需要带 Compose 的 Docker。拉取 `ghcr.io/finogeeks/finguard` 与
`ghcr.io/finogeeks/finguard-mock-erp`。自带 Postgres 与 mock ERP。桩身份。

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

或在克隆目录中：

```bash
./try.sh
./try.sh --down
```

实验只证明产品过程（前门、恰好一次重放）。**不能** 证明你们的 IdP 或真实 ERP。

## 集群安装

你们自己的 Postgres 16+、IdP JWKS、以及一条真实写接口。同一产品镜像，图表在
[`distribution/helm/finguard/`](distribution/helm/finguard/)：

- [快速开始](docs/getting-started.zh.md) — 本机实验
- [集群安装](docs/install-cluster.zh.md) — Helm
- [保护第一个存量服务](docs/customer-deploy.zh.md) — 切流

## 运维技能（给 AI Agent）

- [finguard-try](skills/finguard-try/SKILL-zh.md) — 跑本机实验
- [finguard-customer-deploy](skills/finguard-customer-deploy/SKILL-zh.md) — Helm + 第一条写接口

## 镜像

| 镜像 | 内容 |
| --- | --- |
| `ghcr.io/finogeeks/finguard:<version>` | 产品：`finguard` + 钉死的 agentgateway |
| `ghcr.io/finogeeks/finguard-mock-erp:<version>` | 仅实验夹具 |

钉死版本。生产不要跑 `:latest`。Postgres **不在** 产品镜像里。

若 GHCR 包仍为私有，先 `docker login ghcr.io`，或在已导入镜像后设 `FINGUARD_SKIP_PULL=1`。
