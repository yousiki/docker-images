# cluster-dev

Reproducible Docker images for deep-learning development on GPU and CPU
hosts. Each tool is installed by its **upstream-recommended** path
(no ad-hoc curl-from-releases when the project ships an official Docker image).

## Image variants

| Tag                                | Base                                               | What's inside                                                                           |
|------------------------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------|
| `ghcr.io/yousiki/cluster-dev:base`    | `nvidia/cuda:13.2.1-cudnn-devel-ubuntu24.04`        | `uv` + `bun` only. Smallest GPU image; ideal for `uv run` / `bunx` workflows.           |
| `ghcr.io/yousiki/cluster-dev:latest`  | `nvidia/cuda:13.2.1-cudnn-devel-ubuntu24.04`        | Built `FROM` `:base`, plus the full CLI toolchain + zsh dotfiles described below.        |
| `ghcr.io/yousiki/cluster-dev:cpu`     | `ubuntu:24.04`                                      | Same toolchain as `:latest` but without CUDA. Smaller image, good for CPU-only jobs.    |

The `:base` and `:latest` tags ship the same CUDA cuDNN-devel base layer
— only the user-space tooling differs — so pulling `:latest` after `:base`
just adds the toolchain layers.

## Toolchain (in `:latest` and `:cpu`)

| Tool                                       | Install method                                                                  |
|--------------------------------------------|---------------------------------------------------------------------------------|
| `uv` / `uvx`                               | `COPY --from=ghcr.io/astral-sh/uv` (Astral's distroless image)                  |
| `bun` / `bunx`                             | `COPY --from=oven/bun:1-debian` (glibc-compatible variant)                      |
| `node` 24 LTS + `npm` + `npx`              | `COPY --from=node:24-bookworm-slim` (per nodejs/docker-node Best Practices)     |
| `btop` / `gdu` / `yazi` / `zellij` / `starship` | upstream musl/static release tarballs, pinned via build args                |
| `zsh` (+ autosuggestions, syntax-highlighting), `tmux`, `htop` | Ubuntu apt                                                  |
| Build / QoL                                | `build-essential`, `cmake`, `ninja-build`, `git`, `git-lfs`, `ripgrep`, `fd`, `bat`, `jq`, `tree`, `vim`, `nano`, `zoxide`, `fzf` |

The default user is `dev` (UID/GID 1000) with passwordless `sudo` and `zsh`
as login shell. PID 1 is `tini` so signals (Ctrl-C, SIGTERM) propagate
cleanly into long-running training jobs.

## Dotfiles

Configs are derived from the public chezmoi repo at
[`yousiki/chezmoi`](https://github.com/yousiki/chezmoi); only the parts that
make sense in a stateless Docker image are baked in. Anything that depends on
Homebrew, OrbStack, or a chezmoi-managed host-state file is intentionally
omitted. The result: opening a shell in the image gives the same prompt and
`btop`/`zellij`/`bat` look-and-feel as my host machines, with Catppuccin Mocha
as the consistent theme across them.

| File                              | Source in chezmoi                            |
|-----------------------------------|----------------------------------------------|
| `~/.zshrc`, `~/.zprofile`         | `dot_zshrc`, `dot_zprofile` (trimmed)        |
| `~/.config/zsh/{10-base,20-tools,30-local}.zsh` | `dot_config/zsh/*.zsh` (trimmed) |
| `~/.config/starship.toml`         | `dot_config/starship.toml`                   |
| `~/.config/btop/btop.conf`        | `dot_config/btop/btop.conf`                  |
| `~/.config/bat/config`            | `dot_config/bat/config`                      |
| `~/.config/zellij/config.kdl`     | `dot_config/zellij/config.kdl`               |
| `~/.config/{btop,bat}/themes/`    | Catppuccin theme assets, fetched at build time |

There is **no** `~/.tmux.conf` baked in — `zellij` is the primary terminal
multiplexer in these images, and `tmux` is left at its upstream defaults for
the rare cases where you still want it.

## Build locally

```bash
# GPU base (CUDA + uv + bun)
docker buildx build \
  --target base \
  -f cluster-dev/Dockerfile \
  -t cluster-dev:base \
  ./cluster-dev

# GPU full (everything)
docker buildx build \
  --target full \
  -f cluster-dev/Dockerfile \
  -t cluster-dev:latest \
  ./cluster-dev

# CPU (full toolchain, no CUDA)
docker buildx build \
  -f cluster-dev/Dockerfile.cpu \
  -t cluster-dev:cpu \
  ./cluster-dev
```

Override pinned upstream sources via build args (same set across all variants):

```bash
docker buildx build \
  --target full \
  --build-arg CUDA_VERSION=13.2.1 \
  --build-arg UV_VERSION=0.11.8 \
  --build-arg BUN_TAG=1-debian \
  --build-arg NODE_TAG=24-bookworm-slim \
  --build-arg BTOP_VERSION=1.4.6 \
  --build-arg GDU_VERSION=5.36.1 \
  --build-arg YAZI_VERSION=26.1.22 \
  --build-arg ZELLIJ_VERSION=0.44.1 \
  --build-arg STARSHIP_VERSION=1.25.0 \
  -f cluster-dev/Dockerfile \
  -t cluster-dev:local \
  ./cluster-dev
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

CPU image — same shape, drop `--gpus`:

```bash
docker run --rm -it ghcr.io/yousiki/cluster-dev:cpu
```

## CI / publishing

`.github/workflows/cluster-dev.yml` builds on:

- push to `main` that touches `cluster-dev/**`
- version tags matching `cluster-dev/v*` (e.g. `cluster-dev/v1.0.0` → `:1.0.0`)
- pull requests touching `cluster-dev/**` (build only, no push)
- manual `workflow_dispatch`

Three variants are built in parallel via a workflow matrix:

| Variant | Dockerfile             | Target | Tags on `main` | Tags on commit / PR / branch / version |
|---------|------------------------|--------|----------------|----------------------------------------|
| Base    | `Dockerfile`           | `base` | `base`         | `base-sha-<short>`, `base-<branch>`, `base-pr-<n>`, `base-<version>` |
| Full    | `Dockerfile`           | `full` | `latest`       | `sha-<short>`, `<branch>`, `pr-<n>`, `<version>` |
| CPU     | `Dockerfile.cpu`       | —      | `cpu`          | `cpu-sha-<short>`, `cpu-<branch>`, `cpu-pr-<n>`, `cpu-<version>` |

`<version>` is extracted from `cluster-dev/v<version>` git tags.

Images are pushed to **GHCR** (always) and **Docker Hub** (when `DOCKERHUB_USERNAME`
repo variable is set — see [DOCKERHUB.md](./DOCKERHUB.md) for the one-time setup):

```
ghcr.io/yousiki/cluster-dev:<tag>
docker.io/<DOCKERHUB_USERNAME>/cluster-dev:<tag>
```

The Docker Hub copy is produced by a `regctl image copy` step that runs
after the GHCR push — Docker Hub's CDN rejects buildx's monolithic blob PUT
with `400 Bad request` for the large cudnn-devel layer; regctl uses chunked
uploads which work regardless of layer size.

GHA cache is scoped per-variant (`cluster-dev-base`, `cluster-dev-full`,
`cluster-dev-cpu`) so the variants don't trash each other's cache.
