# Contributing

**中文：** [CONTRIBUTING-zh.md](CONTRIBUTING-zh.md)

This public repository is a **documentation and install pack**. Engine source is
not here.

| Kind | How |
| --- | --- |
| Bugs in `try.sh`, Helm values, or docs | Open a GitHub issue on this repo |
| Product / engine changes | Maintainers land them upstream and sync this tree on release |

Do not send engine patches here. Do not expect a source checkout from this
repository.

Each public release rsyncs the upstream public pack (README, `try.sh`, docs,
skills, lab Compose) plus the Helm chart onto `main`. Maintainers can also
sync docs without publishing a new GHCR image.
