# Operator console

中文：[operator-console.zh.md](operator-console.zh.md)

FinGuard serves a **web console** from the same HTTP bind as `/v1/journal`. It is
a renderer over existing APIs (catalog, sessions, halts, secrets, alerts). It is
not a second store, not a login product, and not GA by itself.

Do not claim GA, 信创, or 密评 because you opened this page.

## Open it

| Setup | URL |
| --- | --- |
| Laptop `try.sh` | `http://127.0.0.1:19191/console` |
| Helm | Service port **8088** — `kubectl port-forward svc/finguard 8088:8088` then `http://127.0.0.1:8088/console` |

```bash
# Page loads without a token (HTML only).
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:19191/console
# expect 200
```

Helm NOTES print the HTTP port after install.

## What to paste

Views call `/v1/catalog`, `/v1/sessions`, `/v1/halts`, `/v1/secrets`, and
`/v1/alerts`. Those APIs take a **caller JWT** whose payload includes
`admin_role`:

| `admin_role` | Views |
| --- | --- |
| `system` | Overview, Catalog |
| `security` | Overview, Controls (halt declare / list / lift), Secrets (metadata only) |
| `audit` | Sessions |

Mint that claim in your IdP (same RS256 JWT + JWKS as [identity-iam.md](identity-iam.md)).
Paste the JWT into the console. There is **no SSO login page**.

The API verifies `admin_role`. A Role dropdown (on older page builds) does not
grant access. Spoofed `x-finguard-admin-role` is ignored.

**Not a customer pass:** stub identity (`try.sh`), HS256, empty JWKS, or the
compose admin token (`local-compose-token`) as a substitute for `admin_role`.
On the laptop lab, the page opens and the views return **403** until OIDC is
wired. That is expected.

When OIDC is on, the console sends the JWT as `Authorization: Bearer` and as
`x-finguard-id-token`. Agent writes still use the two-header split in
[identity-iam.md](identity-iam.md) (`Authorization` = admin token,
`x-finguard-id-token` = caller JWT). Do not mix those modes.

## What you did not prove

- Design-partner walkthrough of the three roles (GA-gating per §24.0)
- Your IdP, just because Helm `oidc.*` is set
- Signed supply chain (pin digest; [supply-chain.md](supply-chain.md))
