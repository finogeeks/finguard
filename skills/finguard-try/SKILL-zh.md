---
name: finguard-try
description: >
  用 try.sh 从 GHCR 拉起 FinGuard 本机实验（Compose：产品镜像、mock ERP、自带
  Postgres）。用户要五分钟安装、验证恰好一次写入、或不克隆源码先看 FinGuard 时使用。
---

# FinGuard 本机实验

**工作目录：** 公开包根目录（`finogeeks/finguard` 克隆，或私有树里的
`docs/public-finguard/`）。

## 硬规则

1. 本实验是 mock ERP + 桩身份 + 未签名镜像。不要说成生产 IdP 证明、设计伙伴 ERP 证明、GA、信创或密评。
2. 不要从引擎源码 `docker build`。拉取（或 skip-pull）GHCR 标签。
3. 不要把客户集群指到 mock ERP。
4. 除非用户接受并披露 pin 时补丁，否则不要打开 `FINGUARD_MCP_REPLAY=patched`。

## 运行

需要 Docker Compose、`curl`、`python3`。公开仓库就绪后的一键：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
```

在包装目录中：

```bash
chmod +x ./try.sh
./try.sh
```

镜像已在本地（不拉 GHCR）：

```bash
FINGUARD_SKIP_PULL=1 ./try.sh
```

脚本打印 `OK: erp writes=1 (replay held exactly-once)` 并列出
`:13000` / `:19191` / `:18080` 即为通过。然后做集成检查：

```bash
./lab-exercises.sh
```

手册：https://github.com/finogeeks/finguard/blob/main/docs/lab.zh.md

管理 Bearer：`local-compose-token`。

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' http://127.0.0.1:19191/metrics | head
```

停止：`./try.sh --down`。

## 拉取失败

GHCR 包默认私有。`docker login ghcr.io`，或导入厂商提供的镜像并设 `FINGUARD_SKIP_PULL=1`。
没有 arm64 标签时，Apple Silicon 用 amd64 模拟 —— 更慢，实验仍有效。

## 下一步

真实 Postgres + IdP + 真实写路径：技能 `finguard-customer-deploy` 与
https://github.com/finogeeks/finguard/blob/main/docs/install-cluster.zh.md
