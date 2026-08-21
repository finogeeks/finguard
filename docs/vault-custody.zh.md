# 把 FinGuard 接到 Vault（凭证托管）

English: [vault-custody.md](vault-custody.md)

FinGuard 可以在 **放行时注入企业凭证**，让智能体永远拿不到 ERP/CRM 密钥。密钥放在你们
Vault 兼容的 KV（实验室也可用进程环境变量）。FinGuard 不替代 HashiCorp Vault、
OpenBao 或你们的密管，产品镜像里也不带 Vault 服务。

**没有按厂商编写的 Vault 插件。** HashiCorp、OpenBao 和实验性 RustyVault 能接上，
是因为它们提供 FinGuard 已调用的 KV HTTP API。

**状态：** 已签名 `0.1.0` 镜像 — 钉 digest 并按
[supply-chain.zh.md](supply-chain.zh.md) 校验。不要宣称 GA。本机实验（`try.sh`）**不**启动 Vault，
也不能证明托管。

相关：[install-cluster.zh.md](install-cluster.zh.md)、[customer-deploy.zh.md](customer-deploy.zh.md)、
[identity-iam.zh.md](identity-iam.zh.md)。

---

## 1. 托管是什么（以及不是什么）

放行一笔写时，FinGuard 加上一个头（例如 `x-erp-token`），值来自密钥源。智能体请求
不带该密钥。不带该头直连后端必须失败。

| 模式 | 何时 | 算客户验收通过？ |
| --- | --- | --- |
| Vault / OpenBao KV（`FINGUARD_VAULT_ADDR` + token） | 生产托管 | 是，前提是后端拒绝无凭证请求 |
| `--inject-from-env` / `FINGUARD_INJECT_FROM_ENV` | 本机 / 起步 | **否** — 环境变量快照，不是 Vault |
| 无注入头、无 Vault | 实验默认（`try.sh`） | **否** — 智能体或 mock ERP 仍可能“能跑” |

`FINGUARD_ADMIN_TOKEN` 是 FinGuard HTTP 管理 Bearer，**不是** ERP 密钥。不要混用。

---

## 2. 你们的 Vault 必须提供什么

FinGuard 从 Pod 打 Vault HTTP API：

1. `GET {addr}/v1/sys/health`，带 `X-Vault-Token` —— **`serve` 启动时必达**。
   Vault 不可达则进程退出。
2. `GET {addr}/v1/{secret_path}` —— 每次注入读 KV。HashiCorp/OpenBao KV v2 路径
   一般是 `secret/data/<name>`。

JSON 须在 `/data/data/<key>`（KV v2）或 `/data/<key>` 给出注入键。默认键名 `token`
（`FINGUARD_INJECT_SECRET_KEY`）。

若后来 KV 读取失败，FinGuard **不加**该头并打警告。它不会单凭这一点把写变成拒绝。
后端 **必须** 拒绝没有凭证的请求。

**不算客户验收通过：** Compose 开发 Vault 配 root 令牌、把 RustyVault 当成信创或密评、
环境变量注入、空的 Vault 地址。

---

## 3. 配置 FinGuard

Helm 图表 **不** 模板化 Vault 开关。叠加环境变量（若更想用命令行，则是 `serve` 上的
同名参数）。

| 环境变量 | 参数 | 作用 |
| --- | --- | --- |
| `FINGUARD_VAULT_ADDR` | `--vault-addr` | 基址，尾斜杠可有可无 |
| `FINGUARD_VAULT_TOKEN` | `--vault-token` | 对该 KV 路径有读权限的令牌。不是管理令牌 |
| `FINGUARD_VAULT_SECRET_PATH` | `--vault-secret-path` | 默认 `secret/data/erp` |
| `FINGUARD_SECRET_BACKEND` | `--secret-backend` | `hashicorp`（默认）、`openbao` 或 `rustyvault` |
| `FINGUARD_INJECT_SECRET_KEY` | `--inject-secret-key` | 密钥 JSON 里的键（默认 `token`） |
| `FINGUARD_INJECT_HEADER` | `--inject-header` | 放行时加上的头名（如 `x-erp-token`） |

Helm 安装后的 Secret + 叠加示例：

```bash
kubectl create secret generic finguard-vault \
  --from-literal=FINGUARD_VAULT_TOKEN='s.…'

kubectl set env deploy/finguard \
  FINGUARD_SECRET_BACKEND=hashicorp \
  FINGUARD_VAULT_ADDR='https://vault.example.svc:8200' \
  FINGUARD_VAULT_SECRET_PATH='secret/data/erp' \
  FINGUARD_INJECT_SECRET_KEY=token \
  FINGUARD_INJECT_HEADER=x-erp-token

kubectl set env deploy/finguard --from=secret/finguard-vault
```

FinGuard Pod 必须能 **GET** `FINGUARD_VAULT_ADDR`（出站、DNS、TLS 信任）。叠加后
重启 Pod。此时 `finguard doctor` 应报告 `secret_source: vault/hashicorp`（或
`vault/openbao`）。

写入 KV（HashiCorp/OpenBao；路径随挂载而变）：

```bash
vault kv put secret/erp token='the-erp-credential-agents-must-not-see'
```

把 `FINGUARD_VAULT_SECRET_PATH` 钉成 FinGuard 实际 GET 的 API 路径（KV v2 上是
`secret/data/erp`），不要只抄 `vault kv` 命令里的名字。

OpenBao 用同一套客户端。设 `FINGUARD_SECRET_BACKEND=openbao`，把
`FINGUARD_VAULT_ADDR` 指到 OpenBao 监听地址。

RustyVault 是 **实验性**（无官方镜像，路径常常是 `secret/erp` 而不是
`secret/data/erp`）。它不是信创或密评证据。

---

## 4. 智能体接入前验收

1. 后端没有注入头 → **401**（或等价）。若 ERP 接受无凭证写入，托管不成立。
2. 经 FinGuard 写（绿地 `:13000` 或已有边缘），**不**发送 ERP 密钥 → 成功，且后端看到注入头。
3. 启动时 Vault 令牌错误或缺失 → `serve` / Pod 崩溃循环（`vault health`）。
4. Doctor（源码目录）：设置了 Vault 环境时 `secret_source` 为 `vault/hashicorp` 或
   `vault/openbao`，不是 `env`。

桩身份与托管彼此独立。IdP 接线：[identity-iam.zh.md](identity-iam.zh.md)。

---

## 5. 不要宣称

- 本机 `try.sh` 通过 = 已证明 Vault 托管
- 叠加了 Vault 环境变量 = GA、信创或密评
- Compose Vault 或实验性 RustyVault = 密评或信创目录
- 未钉 digest 的漂浮 `:0.1.0` 标签 = 已签名供应链
- 环境变量注入（`FINGUARD_INJECT_FROM_ENV`）= 客户 Vault 验收通过
