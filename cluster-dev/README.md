# cluster-dev

A reproducible Docker image for deep-learning development on GPU clusters. Each tool is installed by its **upstream-recommended** path (no ad-hoc curl-from-releases when the project ships an official Docker image).

## What's inside

| Tool                               | Install method (upstream-recommended)                          |
|------------------------------------|----------------------------------------------------------------|
| Base                               | `nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04`                   |
| `uv` / `uvx`                       | `COPY --from=ghcr.io/astral-sh/uv:0.11.8` (Astral's distroless image) |
| `bun` / `bunx`                     | `COPY --from=oven/bun:1-debian` (glibc-compatible variant)     |
| `node` 22 LTS + `npm` + `npx`      | `COPY --from=node:22-bookworm-slim` (per nodejs/docker-node Best Practices) |
| `btop`                             | upstream musl release tarball (`make install`, includes themes) |
| `gdu`                              | upstream `_static` binary release                              |
| `yazi` (+ `ya`)                    | upstream musl release zip                                       |
| `zellij`                           | upstream musl release tarball                                   |
| `tmux`, `zsh` (+ autosuggestions, syntax-highlighting), `htop` | Ubuntu apt |
| Build / QoL                        | `build-essential`, `cmake`, `ninja-build`, `git`, `git-lfs`, `ripgrep`, `fd`, `bat`, `jq`, `tree`, `vim`, `nano` |

The default user is `dev` (UID/GID 1000) with passwordless `sudo` and `zsh` as login shell. PID 1 is `tini` so signals (Ctrl-C, SIGTERM) propagate cleanly into long-running training jobs.

## `:base` — minimal smoke-test variant

A second, intentionally-minimal image is published alongside the full one for
diagnosing cluster pull/start failures (e.g. private-registry mirrors with
limited egress, disk-pressure on the node, broken cluster networking).

It contains **only**:

- `nvidia/cuda:13.0.1-base-ubuntu24.04` (the lightweight `-base-` CUDA variant — no cuDNN, no devel toolchain)
- `uv` / `uvx`
- `bun` / `bunx`
- `ca-certificates`

Built from `Dockerfile.base` and published as:

```
ghcr.io/yousiki/cluster-dev:base
ghcr.io/yousiki/cluster-dev:base-sha-<short>
```

Run it the same way:

```bash
docker run --rm -it --gpus all ghcr.io/yousiki/cluster-dev:base
```

If `:base` runs but `:latest` does not, the regression is in the dev tooling
layer — not the CUDA base or the cluster's GPU runtime.

## Build locally

From this directory:

```bash
docker buildx build -t cluster-dev:local .
```

Override pinned upstream sources via build args:

```bash
docker buildx build \
  --build-arg CUDA_VERSION=13.0.1 \
  --build-arg UV_VERSION=0.11.8 \
  --build-arg BUN_TAG=1-debian \
  --build-arg NODE_TAG=22-bookworm-slim \
  --build-arg BTOP_VERSION=1.4.6 \
  --build-arg GDU_VERSION=5.36.0 \
  --build-arg YAZI_VERSION=26.1.22 \
  --build-arg ZELLIJ_VERSION=0.44.1 \
  -t cluster-dev:local .
```

## Run

```bash
docker run --rm -it --gpus all \
  -v "$PWD":/workspace -w /workspace \
  ghcr.io/yousiki/cluster-dev:latest
```

Match host UID/GID (common on shared clusters):

```bash
docker run --rm -it --gpus all \
  --user "$(id -u):$(id -g)" \
  -v "$PWD":/workspace -w /workspace \
  ghcr.io/yousiki/cluster-dev:latest
```

## CI / publishing

`../.github/workflows/cluster-dev.yml` (at repo root) builds on:

- push to `main` that touches `cluster-dev/**`
- version tags matching `cluster-dev/v*` (e.g. `cluster-dev/v1.0.0` → `:1.0.0`)
- manual `workflow_dispatch`

Pull requests build but do not push.

Images are pushed to:

- **GHCR** — always, both variants.
- **Docker Hub** — `:base` variant only, when `DOCKERHUB_USERNAME` repo variable is set (see [DOCKERHUB.md](./DOCKERHUB.md) for the one-time setup). The `full` variant is GHCR-only because its cudnn-devel layer exceeds Docker Hub's per-blob upload limit (the API returns `400 Bad request` on the monolithic PUT).

```
ghcr.io/yousiki/cluster-dev:<tag>           # full + base variants
docker.io/<DOCKERHUB_USERNAME>/cluster-dev:base[-...]   # base variant only
```

Two variants are built in parallel via a workflow matrix:

| Variant | Dockerfile | Registries | Tags on `main` | Tags on commit / PR / branch / version |
|---------|-----------|-----------|----------------|----------------------------------------|
| Full    | `Dockerfile`      | GHCR        | `latest` | `sha-<short>`, `<branch>`, `pr-<n>`, `<version>` |
| Base    | `Dockerfile.base` | GHCR + DH   | `base`   | `base-sha-<short>`, `base-<branch>`, `base-pr-<n>`, `base-<version>` |

`<version>` is extracted from `cluster-dev/v<version>` tags. Pull requests build but do not push.

GHA cache is scoped per-variant (`scope=cluster-dev`, `scope=cluster-dev-base`) so the variants don't trash each other's cache.
