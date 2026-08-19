# Connect FinGuard to your IAM

中文：[identity-iam.zh.md](identity-iam.zh.md)

FinGuard verifies **caller JWTs** issued by your existing identity provider
(IdP). It does not replace Okta, Microsoft Entra ID, Keycloak, Zitadel, Auth0,
or an on-prem IAM suite, and it does not host a login page.

There is **no vendor IAM plugin**. Keycloak and Zitadel are not special: they
work only because they mint the RS256 JWT + JWKS contract below. An in-house
IAM, CAS, 4A platform, or regional IdP is supported the same way — or via a
thin token broker if the directory cannot mint that contract. See §3.

**Status:** unsigned image, no SBOM. Do not claim GA. The laptop lab (`try.sh`)
uses **stub identity** and does not prove your IdP.

Related: [install-cluster.md](install-cluster.md), [customer-deploy.md](customer-deploy.md).

---

## 1. Two credentials (do not mix them)

| Credential | Who holds it | What it is for |
| --- | --- | --- |
| Admin token (`FINGUARD_ADMIN_TOKEN`) | Operators / the gateway that calls FinGuard HTTP | Bearer on `/v1/*` admin APIs (`/v1/journal`, manifests, `POST /v1/decide`, …) |
| Caller JWT from your IdP | Agent or workload | Who is acting. Verified against your issuer + JWKS |

The admin token is **not** company SSO. This pack has no FinGuard admin console
and no SAML/OIDC login UI for humans.

When FinGuard HTTP APIs need both (for example `POST /v1/actions/invoke` or
`POST /v1/decide`), send:

```http
Authorization: Bearer <admin-token>
x-finguard-id-token: <caller-jwt>
```

Do not put the caller JWT in `Authorization` on those APIs — that header is the
admin token. On the **greenfield data plane** (agentgateway `:13000`), the agent
sends `x-finguard-id-token` on the write request; FinGuard reads it from the
forwarded headers.

---

## 2. What your IAM must issue

Production path: **RS256 JWT + JWKS** (or an RSA public PEM if FinGuard cannot
reach JWKS).

| JWT field | Rule |
| --- | --- |
| `alg` | `RS256` |
| `iss` | Exact string match of `oidc.issuer` (trailing slash matters) |
| `aud` | Must include `oidc.audience` (Helm default: `finguard`) |
| `sub` | Workload / client subject; recorded as caller |
| `exp` | Required. Clock leeway is **0** — expired tokens are rejected |
| `act.sub` | Required when the Action Manifest uses `auth.mode: obo_user` (RFC 8693 `act` claim). This is the **human**. Token `sub` alone is not enough |

JWKS must be a standard `{"keys":[…]}` document with at least one `kty: RSA`
key. FinGuard fetches it over HTTP(S) from the pod.

**Not a customer pass:** empty JWKS (stub identity), HS256 shared-secret JWTs.

### What FinGuard does not speak

- SAML 2.0, LDAP bind, Kerberos, ADFS WS-Federation as a wire protocol
- Authorization-code, device-code, or interactive login inside FinGuard
- Using a god service-account `sub` to satisfy `obo_user`

If your directory is SAML or LDAP only, put an OIDC layer in front (Entra, Okta,
Keycloak, Zitadel, …) and mint JWTs for agents. That layer can be a product you
already run, or the thin broker in §3 — FinGuard still only verifies JWTs.

---

## 3. Custom / in-house IAM (not Keycloak or Zitadel)

Do not add a FinGuard adapter per customer IdP. Wire the **token contract** in
§2, or put a broker in front of the directory.

| What they have today | Support path | Not a support path |
| --- | --- | --- |
| Any issuer that already mints **RS256 JWT** + a JWKS URL the FinGuard pod can GET | Helm `oidc.issuer` + `oidc.audience` + `oidc.jwksUrl` copied from a **real token**. Same steps as Keycloak. | A vendor-specific connector, realm export, or SAML metadata file |
| RS256 JWT yes, but the pod cannot reach JWKS (air-gap, split DNS) | Overlay `FINGUARD_OIDC_RSA_PEM` (IdP **public** key). Issuer still required. | HS256 shared secret as a customer pass |
| Directory is SAML, LDAP, Kerberos, CAS, or ADFS WS-Federation only | Enable OIDC on that product if it has it (CAS 6+, many 4A suites), **or** run a thin JWT broker. FinGuard still verifies JWTs. | Teaching FinGuard to bind LDAP or consume SAML assertions |
| Edge already verified mTLS and forwards Envoy `x-forwarded-client-cert`; no JWT program | Overlay `FINGUARD_MTLS_TRUST_XFCC=true`. High assurance for the workload. `obo_user` still needs JWT `act.sub`. | Using XFCC instead of JWKS on an OIDC engagement; spoofable `x-finguard-acted-as` |
| Cannot mint RS256 and will not add a broker | **Blocker.** Record it. Do not ship stub identity. | Empty JWKS / stub / HS256 as production identity |

### Thin broker (customer or SI scope)

When the directory cannot mint the §2 JWT, run a small issuer **outside**
FinGuard:

1. Authenticate the agent against the customer's IAM with the protocol they
   already have.
2. Mint a short-lived RS256 JWT: `iss`, `aud` (Helm `oidc.audience`, or the API
   id they already use), `sub` (workload), `exp`, and `act.sub` when the Action
   Manifest is `obo_user`.
3. Publish a standard JWKS `{"keys":[…]}` with `kty: RSA`, **or** give
   operations the RSA public PEM to mount.
4. Agents send that JWT as `x-finguard-id-token`.

The broker is not a FinGuard crate, Helm subchart, or certified IdP. Copy `iss`
from a token the broker actually issues — trailing slashes count.

---

## 4. Configure FinGuard (Helm)

Set issuer, audience, and JWKS. Empty `jwksUrl` keeps stub identity.

```bash
helm upgrade --install finguard distribution/helm/finguard \
  --set image.tag=0.1.0 \
  --set agentgateway.backendHost='erp.example.svc:80' \
  --set oidc.issuer='https://idp.example.com/realms/prod' \
  --set oidc.audience=finguard \
  --set oidc.jwksUrl='https://idp.example.com/realms/prod/protocol/openid-connect/certs'
```

Same values as env (Compose / overlay):

| Helm | Env |
| --- | --- |
| `oidc.issuer` | `FINGUARD_OIDC_ISSUER` |
| `oidc.audience` | `FINGUARD_OIDC_AUDIENCE` (default `finguard`) |
| `oidc.jwksUrl` | `FINGUARD_OIDC_JWKS_URL` |

The FinGuard pod must be able to **GET** `jwksUrl` (egress / firewall / TLS
trust). If it cannot, overlay RSA PEM instead of JWKS:

- `FINGUARD_OIDC_ISSUER` still required
- `FINGUARD_OIDC_RSA_PEM` = path to the IdP's RSA **public** key PEM

The chart does not template that PEM path today — add it with extra env / a
mounted Secret.

Optional: if the edge already verified mTLS and forwards Envoy
`x-forwarded-client-cert`, overlay `FINGUARD_MTLS_TRUST_XFCC=true`. That is
not a substitute for wiring JWKS on an OIDC engagement.

---

## 5. Configure your IdP

Vendor-agnostic checklist:

1. Create an **API / resource** (or authorization server) whose audience you
   will mint on agent tokens. Either:
   - mint `aud=finguard` (matches Helm default), or
   - set `oidc.audience` to the audience your IAM already uses (client ID or
     API identifier).
2. Create a **confidential client** (or workload identity) for the agent
   runtime. Grant it permission to request that API.
3. Publish JWKS. Confirm FinGuard can fetch it from the cluster.
4. Copy the issuer string from a **real token's** `iss` claim — do not guess.
   Discovery metadata (`/.well-known/openid-configuration`) `issuer` must match
   the claim exactly.
5. For `obo_user` writes, emit RFC 8693 `act: { "sub": "<human id>" }` on the
   token. If your IdP has no `act` claim, map it with a token customization
   (custom claim, token exchange, or a thin broker in front of FinGuard).
   FinGuard **ignores** `x-finguard-acted-as` when OIDC is on, so a free-form
   spoof header cannot satisfy on-behalf-of.

Typical issuer / JWKS URLs (replace placeholders; confirm against discovery):

| IdP | Typical `issuer` | Typical JWKS |
| --- | --- | --- |
| Microsoft Entra ID | `https://login.microsoftonline.com/<tenant-id>/v2.0` | `https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys` |
| Okta (custom auth server) | `https://<domain>/oauth2/<authServerId>` | `https://<domain>/oauth2/<authServerId>/v1/keys` |
| Keycloak | `https://<host>/realms/<realm>` | `https://<host>/realms/<realm>/protocol/openid-connect/certs` |
| Zitadel | `https://<instance>` (pin discovery `issuer`) | `https://<instance>/oauth/v2/keys` |
| Auth0 | `https://<tenant>.auth0.com/` | `https://<tenant>.auth0.com/.well-known/jwks.json` |

These products are **not** certified integrations. They work when they mint
RS256 JWTs whose `iss` / `aud` match Helm and whose JWKS is reachable. Pin the
strings your tenant actually issues. An unnamed in-house issuer uses the same
three Helm values — see §3.

---

## 6. Agent and gateway wiring

**Greenfield** (`agentgateway.enabled=true`): agents call the FinGuard Service
on port **13000**, never the raw ERP. Forward `x-finguard-id-token` on each
governed write.

**Existing Envoy-family edge:** `ext_authz` + `ext_proc` to FinGuard gRPC
(`:19090`), `failureMode: deny` / `failClosed`. Forward the caller JWT header
(and do not strip it).

**Other edges:** `POST /v1/decide` with `{"method","path","body"}`, admin
Bearer, and `x-finguard-id-token`.

---

## 7. Validate before agents

Wrong `iss`, wrong `aud`, or expired JWT → **401**. A valid JWT with `act.sub`
must journal the human, not a service-account `sub`, when the manifest is
`obo_user`.

```bash
# Expect 401 (wrong issuer). HTTP bind in Helm is :8088.
curl -s -o /tmp/oidc-iss.json -w '%{http_code}' \
  -H "Authorization: Bearer $FINGUARD_ADMIN_TOKEN" \
  -H "x-finguard-id-token: $WRONG_ISS_JWT" \
  -H 'content-type: application/json' \
  -d '{"action_id":"erp.invoice.pay","manifest_version":"1","parameters":{}}' \
  "http://${HTTP}/v1/actions/invoke"
```

Stub / HS256 identity is not a customer pass. Full cutover matrix:
[customer-deploy.md](customer-deploy.md).

---

## 8. What not to claim

- Laptop `try.sh` PASS = your IdP is proven
- Setting Helm `oidc.*` = GA, 信创, or 密评
- Unsigned `ghcr.io/finogeeks/finguard` = signed supply chain
- A Keycloak, Zitadel, or other vendor connector ships in this product
