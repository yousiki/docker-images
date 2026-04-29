# cluster-dev

A reproducible Docker image for deep-learning development on GPU clusters.

## What's inside

| Layer       | Content |
|-------------|---------|
| Base        | `nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04` (latest CUDA toolkit) |
| Shell       | `zsh` as default (with `zsh-autosuggestions` + `zsh-syntax-highlighting`, sane `.zshrc`) |
| Python      | `uv` + `uvx` (Astral) — interpreter, env & project manager |
| JS / Node   | `bun` (+ `bunx`); `node` 22 LTS + `npm` as bun's fallback |
| Multiplexer | `zellij` (default) and `tmux` (fallback, with `.tmux.conf`) |
| Monitor     | `btop`, `htop` |
| Disk        | `gdu` |
| Files       | `yazi` (+ `ya`) |
| Build       | `build-essential`, `cmake`, `ninja`, `git`, `git-lfs` |
| QoL         | `ripgrep`, `fd`, `bat`, `jq`, `tree`, `vim` |

The default user is `dev` (UID/GID 1000) with passwordless `sudo` and `zsh` as login shell. PID 1 is `tini` so signals (Ctrl-C, SIGTERM) propagate cleanly into long-running training jobs.

## Build locally

From this directory:

```bash
docker buildx build -t cluster-dev:local .
```

Override versions via build args:

```bash
docker buildx build \
  --build-arg CUDA_VERSION=13.0.1 \
  --build-arg UV_VERSION=0.5.18 \
  --build-arg BUN_VERSION=1.1.42 \
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
