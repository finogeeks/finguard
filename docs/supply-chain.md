# Verify a signed FinGuard image (SBOM)

中文：[supply-chain.zh.md](supply-chain.zh.md)

FinGuard's audit chain is only as strong as the binary that wrote it. Releases
from the public pack workflow **sign** `ghcr.io/finogeeks/finguard:<version>`
(by digest) and **attest** an SPDX SBOM. Lab tags published *before* that
pipeline existed are unsigned — `cosign verify` failing on an old tag is
expected.

The public key lives in this repository: [`cosign.pub`](../cosign.pub).

Current signed `0.1.0` digest (2026-08-21):

`sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5`

Same-name tags from before this digest are unsigned. Changelog:
[CHANGELOG.md](../CHANGELOG.md). Do not claim GA.

## Verify (customer / SE)

```bash
# Prefer digest over tag. Helm: --set image.digest=sha256:…
IMG=ghcr.io/finogeeks/finguard@sha256:63206295f5724a814892129ff8129f97a5ec26f4145e6450c80d5f14dce7f7a5

curl -fsSL -o cosign.pub \
  https://raw.githubusercontent.com/finogeeks/finguard/main/cosign.pub

cosign verify --key cosign.pub "$IMG"
cosign verify-attestation --key cosign.pub --type spdxjson "$IMG"
```

`finguard doctor` prints `FINGUARD_IMAGE_DIGEST` when Helm sets `image.digest`,
and the sha256 of the in-image `agentgateway` binary.

## What this does not prove

- 信创 directory listing or 密评
- That your cluster is running that digest (pin `image.digest`; do not float `:latest`)
- Identity of the *operator* who dispatched the workflow — only that the
  digest matches the published key

Mock-ERP images are lab fixtures and are **not** signed.
