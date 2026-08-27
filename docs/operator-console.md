# Operator console

中文：[operator-console.zh.md](operator-console.zh.md)

FinGuard serves a **web console** from the same HTTP bind as `/v1/journal`. It is
a renderer over existing APIs (catalog, sessions, halts, secrets, alerts). It is
not a second store, not a login product, and not GA by itself.

Do not claim GA, 信创, or 密评 because you opened this page.

## Go-live (onboarding)

Catalog go-live is the **console wizard** and the `/v1/onboardings/*` dual-control
APIs (System drafts, Security accepts, `change_ticket_id` required). FinGuard
compiles agentgateway yaml on accept and persists it via **FileSink** when
`FINGUARD_DATAPLANE_YAML` is set (Helm: `/etc/finguard/agentgateway.yaml` when
agentgateway is enabled). The write copies over the existing file so the inode
stays stable for a file watch, then runs `FINGUARD_DATAPLANE_RELOAD_CMD` when
set (Helm: SIGHUP the sidecar via `shareProcessNamespace`). Confirm the
agentgateway build reloads on SIGHUP.

After Security accepts an onboarding, its live Catalog card exposes the non-mutating
cutover probes (`POST /v1/onboardings/{id}/cutover-probes`): unauthenticated-admin
rejection, Prometheus metrics text, audit-chain verification, and fail-closed
generated-yaml posture. Existing-gateway cards mark the yaml probe as skipped
because FinGuard does not own that gateway's route. Production cutover never
sends an ERP write probe.

Do **not** use agentgateway admin `:15000` or `:15000/ui` as an apply path. That
socket is a same-pod debug surface only; the Helm Service does not expose port
15000. Do not POST routes to the admin API or author Traffic Routes by hand.

Compile-time rejections for `auth.downstream: gateway_exchange` (HTTP 409,
`reason` in the body):

| Code | When |
| --- | --- |
| `downstream_exchange_unsupported_topology` | `existing_gateway` topology (FinGuard does not own that yaml) |
| `downstream_exchange_unsupported_protocol` | MCP protocol family |
| `downstream_exchange_conflict` | Manifests on one compiled route disagree on audience / resource / scope |
| `downstream_exchange_unconfigured` | No `FINGUARD_OBO_TOKEN_HOST` / `FINGUARD_OBO_CLIENT_ID` (or secret env is not a `$VAR` reference) |

These fire at Security accept, never at request time.

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
| `system` | Overview, Catalog, Onboard |
| `security` | Overview, Controls (halt declare / list / lift), Secrets (metadata only), live cutover probes |
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
