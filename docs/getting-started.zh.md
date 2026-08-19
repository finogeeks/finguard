# 快速开始 — 本机实验

English: [getting-started.md](getting-started.md)

在工作站上几分钟拉起 FinGuard。**一条命令** 拉起产品栈：FinGuard + 钉死的
agentgateway + Postgres。mock ERP 和桩身份只给实验。未签名镜像。

## 1. 前提

- 带 Compose v2 的 Docker（`docker compose version`）
- `curl`、`python3`，一键安装还需要 `git`
- 能从 `ghcr.io` 拉取（或本地已导入镜像）

## 2. 运行

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

在本仓库克隆中：

```bash
./try.sh
```

钉死版本：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh -s -- --version 0.1.0
```

使用已经构建或导入的镜像：

```bash
FINGUARD_SKIP_PULL=1 ./try.sh
```

脚本会拉取 `ghcr.io/finogeeks/finguard:<version>` 与
`ghcr.io/finogeeks/finguard-mock-erp:<version>`，启动绿地 profile
（FinGuard + agentgateway + Postgres + mock ERP），然后用同一 `Idempotency-Key`
向 `:13000/writes` 写两次，并确认 mock ERP 只发生 **一次** 变更。

## 3. 你应该看到

| URL | 角色 |
| --- | --- |
| `http://127.0.0.1:13000` | 智能体前门（agentgateway） |
| `http://127.0.0.1:19191` | FinGuard HTTP（`/metrics`、`/v1/*`） |
| `http://127.0.0.1:18080` | Mock ERP（仅实验） |

实验管理 Bearer：`local-compose-token`。

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' http://127.0.0.1:19191/metrics | head
```

## 4. 停止

```bash
./try.sh --down
```

## 5. 集成检查

实验起来之后，做流水 / 故障关闭 / Action Manifest 检查：

```bash
./lab-exercises.sh
```

手册：[lab.zh.md](lab.zh.md)。把 HTTP 智能体指到 `http://127.0.0.1:13000`，不要指 mock ERP。

## 6. 下一步

把真实智能体指到真实写接口走集群路径：
[install-cluster.zh.md](install-cluster.zh.md)，然后接 IdP
（[identity-iam.zh.md](identity-iam.zh.md)），可选 Vault 托管
（[vault-custody.zh.md](vault-custody.zh.md)），再
[customer-deploy.zh.md](customer-deploy.zh.md)。

不要把 mock ERP 留在客户集群。不要把本实验当作 IdP 证明。

## 排障

| 现象 | 处理 |
| --- | --- |
| 拉 `ghcr.io/finogeeks/finguard` 出现 `denied` | GHCR 包仍是私有。`docker login`，或已导入镜像后 `FINGUARD_SKIP_PULL=1` |
| 端口 `13000` / `19191` / `18080` 被占用 | 停掉占用进程，或 `./try.sh --down` |
| Apple Silicon / linux/arm64 | 镜像同时发 `linux/amd64` 与 `linux/arm64`。Docker 会选原生架构 |
