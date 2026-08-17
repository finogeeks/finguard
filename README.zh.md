# FinGuard（公开发行包）

**English:** [README.md](README.md) ·
[Docs index](docs/README.md)

FinGuard 是智能体与企业写接口（CRM、ERP、工单、内部 HTTP）之间的运行时治理层。智能体拿不到企业系统的原始凭证。

本仓库是安装文档、本机实验脚本、Helm 与运维技能的 **公开入口**。不含引擎源码。镜像 **未签名、无 SBOM** —— 不要当作 GA 供应链证明。

## 本机实验（建议先做这一步）

**一条命令就是产品。** `try.sh` 用 Compose 一次拉起 FinGuard + 钉死的 agentgateway +
Postgres。这三件不用你自己装。产品镜像里同时有 FinGuard 和 agentgateway（不同入口）。
Postgres 是官方 `postgres:16` 镜像，由脚本拉起。mock ERP 只给实验用。

需要带 Compose 的 Docker。GHCR 提供 `linux/amd64` 与 `linux/arm64`（Apple Silicon /
Graviton 原生 arm64）。桩身份。

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

或在克隆目录中：

```bash
./try.sh
./lab-exercises.sh
./try.sh --down
```

`try.sh` 证明前门和恰好一次重放。`lab-exercises.sh` 再查流水门禁、按智能体方式写入、故障关闭、以及一条示例 Action Manifest。手册：[快速开始](docs/getting-started.zh.md)、[本机集成实验](docs/lab.zh.md)。

若 `docker pull` 返回 `denied`，说明 GHCR 包仍是私有 —— 克隆本仓库解决不了。见 [排障](docs/lab.zh.md#排障)。

实验 **不能** 证明你们的 IdP 或真实 ERP。

## 集群安装

**一条 Helm 命令** 拉起 FinGuard + agentgateway + Postgres。你只要给真实写接口的地址。图表在
[`distribution/helm/finguard/`](distribution/helm/finguard/)：

- [文档索引](docs/README.zh.md)
- [快速开始](docs/getting-started.zh.md) — 本机实验
- [本机集成检查](docs/lab.zh.md) — `try.sh` 之后
- [集群安装](docs/install-cluster.zh.md) — Helm
- [保护第一个存量服务](docs/customer-deploy.zh.md) — 切流

## 运维技能（给 AI Agent）

- [finguard-try](skills/finguard-try/SKILL-zh.md) — 跑本机实验
- [finguard-customer-deploy](skills/finguard-customer-deploy/SKILL-zh.md) — Helm + 第一条写接口

## 镜像

| 镜像 | 内容 |
| --- | --- |
| `ghcr.io/finogeeks/finguard:<version>` | 产品：`finguard` + 钉死的 agentgateway（`linux/amd64`、`linux/arm64`） |
| `ghcr.io/finogeeks/finguard-mock-erp:<version>` | 仅实验夹具（同一平台） |
| `postgres:16-alpine` | 实验库，由 Compose 拉起 —— 不在产品镜像里 |

公开 git 是 [`finogeeks/finguard`](https://github.com/finogeeks/finguard)。钉死版本。生产不要跑 `:latest`。Postgres **不在** 产品镜像里。

若 GHCR 包仍为私有，先 `docker login ghcr.io`，或在已导入镜像后设 `FINGUARD_SKIP_PULL=1`。
