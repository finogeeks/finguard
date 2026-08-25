# Contributing

**中文：** [CONTRIBUTING-zh.md](CONTRIBUTING-zh.md)

This public repository is a **documentation and install pack**. Engine source is
not here.

| Kind | How |
| --- | --- |
| Bugs in `try.sh`, Helm values, docs, or the product | Open a GitHub issue on this repo (label `bug` when you can) |
| Product / engine patches | Do not send PRs here; maintainers fix upstream and sync this tree on publish |

Do not send engine patches here. Do not expect a source checkout from this
repository.

Trusted reporters may get an automated upstream fix PR. Merge does **not**
publish a new GHCR image; a maintainer still runs the signed release.

Each public release rsyncs the upstream public pack (README, `try.sh`, docs,
skills, lab Compose) plus the Helm chart onto `main`. Maintainers can also
sync docs without publishing a new GHCR image.
