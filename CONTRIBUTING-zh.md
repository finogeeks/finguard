# 贡献

**English:** [CONTRIBUTING.md](CONTRIBUTING.md)

本公开仓库是 **文档与安装包**。引擎源码不在这里。

| 类型 | 做法 |
| --- | --- |
| `try.sh`、Helm 值或文档的缺陷 | 在本仓库开 GitHub issue |
| 产品 / 引擎改动 | 由维护者在上游落地，发布时同步本树 |

不要向这里发引擎补丁。不要指望从这个仓库 checkout 源码。

每次公开发布会把上游公开包（README、`try.sh`、文档、技能、实验 Compose）以及 Helm 图表 rsync 到 `main`。
