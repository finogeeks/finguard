# 本机实验 — 集成检查

English: [lab.md](lab.md)

在 [`try.sh`](../try.sh) 打印 `OK: erp writes=1` 之后做这些步骤。本实验是 **REST +
mock ERP + 桩身份**。足够证明智能体可以打在 FinGuard 前面、写入会进流水、以及
FinGuard 挂了会故障关闭。**不能** 当作客户 IdP、真实 ERP，或 SOAP/MCP/A2A 覆盖。

## 1. 实验必须已起来

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/finguard/main/try.sh | sh
# 或在克隆目录中：
./try.sh
```

若 `docker pull` 返回 `denied` / 401，说明 GHCR 包仍是 **私有**。这是维护者在
GitHub 包设置里改可见性，不是本 git 仓库能修的。仅当厂商已给你镜像时：
`docker login ghcr.io`，或 `FINGUARD_SKIP_PULL=1 ./try.sh`。

然后复制下面的 curl，或直接：

```bash
./lab-exercises.sh
```

| URL | 角色 |
| --- | --- |
| `http://127.0.0.1:13000` | 智能体前门（智能体指这里，**不要** 指 ERP） |
| `http://127.0.0.1:19191` | FinGuard 管理 HTTP |
| `http://127.0.0.1:18080` | Mock ERP（仅实验；智能体不得使用此 URL） |

管理 Bearer：`local-compose-token`。

## 2. 管理接口有门禁

```bash
# 无 token → 401
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19191/v1/journal

# 带 token → JSON 数组（含 try.sh 那次写入的流水）
curl -fsS -H 'Authorization: Bearer local-compose-token' \
  http://127.0.0.1:19191/v1/journal | python3 -m json.tool | head
```

审计链校验：

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' \
  -X POST http://127.0.0.1:19191/v1/audit/verify
```

期望 `{"ok":true,...}`。

## 3. 按智能体方式写（集成）

智能体（或代替它的 `curl`）打 **网关**，并带 `Idempotency-Key`。它看不到
Postgres，也拿不到 ERP 密钥。

```bash
KEY="agent-$(date +%s)"
curl -fsS -X POST http://127.0.0.1:13000/writes \
  -H 'content-type: application/json' \
  -H "Idempotency-Key: ${KEY}" \
  -d "{\"batch\":\"allow\",\"run\":\"${KEY}\"}"

# mock ERP 变更次数（仅实验排查）
curl -fsS http://127.0.0.1:18080/writes
```

用同一把 key 再打一次：JSON 里的 `writes` **不得** 增加。

把 HTTP 智能体运行时的企业 base URL 设为 `http://127.0.0.1:13000`，路径
`/writes`。不要给智能体配置 `http://127.0.0.1:18080`。

## 4. 故障关闭

FinGuard 挂了之后，经网关的写请求不得打到 mock ERP（`failureMode: deny` /
`failClosed`）。

```bash
./lab-exercises.sh
# 含：停 FinGuard → POST /writes 失败 → 再启动 → healthz
```

手工：`docker compose -p finguard-try --profile greenfield stop finguard`，然后
POST `:13000/writes`（不得是带新 ERP 写入的 HTTP 200）。继续实验前把容器再拉起来。

## 5. 登记一条实验用 Action Manifest

未登记路径仍可能走 `allow_with_reliability`。登记清单是给智能体要打的那条写命名：

```bash
curl -fsS -H 'Authorization: Bearer local-compose-token' \
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
  http://127.0.0.1:19191/v1/action-manifests
```

## 6. 本实验不能证明什么

| 你看到了 | **没有** 证明 |
| --- | --- |
| 桩调用方身份 | 你们的 IdP JWKS / RS256 / 令牌交换 |
| Mock ERP `/writes` | 真实 CRM/ERP、SOAP、MCP 或 A2A 后端 |
| 未签名的 `ghcr.io/finogeeks/finguard` | 已签名供应链 / SBOM / GA |

集群路径（你们的 Postgres + IdP + 真实写接口）：
[install-cluster.zh.md](install-cluster.zh.md)，然后
[customer-deploy.zh.md](customer-deploy.zh.md)。

## 排障

| 现象 | 处理 |
| --- | --- |
| 拉 GHCR 出现 `denied` / 401 | 包仍是私有。登录，或 skip-pull 厂商镜像 |
| `13000` / `19191` / `18080` 报 `address already in use` | 停掉占用进程，或 `./try.sh --down` 再试 |
| Apple Silicon 很慢 / qemu | 镜像只有 `linux/amd64`；Docker Desktop 模拟是预期行为 |
| `missing required command: python3` | 安装 Python 3；`try.sh` 用它断言写入次数 |
| `curl \| sh` 提示缺 git | 一键脚本会克隆到 `~/.finguard-try`；安装 `git`，或先克隆本仓库再 `./try.sh` |

停止：`./try.sh --down`。
