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

`../.github/workflows/cluster-dev.yml` (at repo root) builds and pushes
to **`ghcr.io/yousiki/cluster-dev`** on:

- push to `main` that touches `cluster-dev/**`
- version tags matching `cluster-dev/v*` (e.g. `cluster-dev/v1.0.0` → `:1.0.0`)
- manual `workflow_dispatch`

Pull requests build but do not push.

Tags emitted by `docker/metadata-action`:

- `latest` — default branch
- `<branch>` — branch refs
- `<version>` — extracted from `cluster-dev/v<version>` tags
- `sha-<short>` — every commit
- `pr-<n>` — pull requests (built only, not pushed)

GHA cache is scoped per-image (`scope=cluster-dev`) so other images in this repo don't compete for cache slots.
