# Verify a signed FinGuard image (SBOM)

中文：[supply-chain.zh.md](supply-chain.zh.md)

FinGuard's audit chain is only as strong as the binary that wrote it. Releases
from the public pack workflow **sign** `ghcr.io/finogeeks/finguard:<version>`
(by digest) and **attest** an SPDX SBOM. Lab tags published *before* that
pipeline existed are unsigned — `cosign verify` failing on an old tag is
expected.

The public key lives in this repository: [`cosign.pub`](../cosign.pub) at the
pack root after the first key ceremony. If that file is missing, no signed
release has been cut yet. Do not treat GHCR as a supply-chain claim.

## Verify (customer / SE)

```bash
# Prefer digest over tag. Helm: --set image.digest=sha256:…
IMG=ghcr.io/finogeeks/finguard@sha256:REPLACE

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
