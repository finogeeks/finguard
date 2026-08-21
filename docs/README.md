# Docs

**中文索引：** [README.zh.md](README.zh.md)

This public repository is an install pack (no engine source). Verify signed
releases with [supply-chain.md](supply-chain.md). Older tags may still be unsigned.

| Doc | Use |
| --- | --- |
| [getting-started.md](getting-started.md) | Bring up the laptop lab (`try.sh`) |
| [lab.md](lab.md) | After the lab is up: journal, fail-closed, point an agent |
| [install-cluster.md](install-cluster.md) | Helm on your cluster (your Postgres + IdP) |
| [identity-iam.md](identity-iam.md) | Connect your IAM / IdP (OIDC JWT + JWKS; vendor-agnostic) |
| [operator-console.md](operator-console.md) | Open `/console`; paste a caller JWT with `admin_role` |
| [vault-custody.md](vault-custody.md) | Connect Vault / OpenBao (credential inject on allow) |
| [supply-chain.md](supply-chain.md) | `cosign verify` + SBOM attestation |
| [customer-deploy.md](customer-deploy.md) | First protected write / cutover |

Skills for AI operators: [../skills/README.md](../skills/README.md).
Helm chart: [../distribution/helm/finguard/README.md](../distribution/helm/finguard/README.md).
