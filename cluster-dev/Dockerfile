# syntax=docker.io/docker/dockerfile:1.7

# ---- Build args (override with --build-arg) -----------------------------
# Pinned to latest stable NVIDIA CUDA release at build time.
# Override with --build-arg CUDA_VERSION=... if you need a different toolkit.
ARG CUDA_VERSION=13.0.1
ARG UBUNTU_VERSION=24.04
ARG BASE_IMAGE=nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

# ============================================================
# Stage 1 — Downloader: fetch single-binary tools into /out
# Uses a small base; binaries are extracted, not executed here.
# ============================================================
FROM debian:bookworm-slim AS downloader

ARG TARGETARCH=amd64
ARG UV_VERSION=0.5.18
ARG BUN_VERSION=1.1.42
ARG GDU_VERSION=5.30.1
ARG YAZI_VERSION=0.4.2
ARG ZELLIJ_VERSION=0.41.2

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl tar unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/dl

# uv (astral-sh) — Python env / project / interpreter manager
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) T=x86_64-unknown-linux-gnu ;; \
      arm64) T=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o uv.tar.gz \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${T}.tar.gz"; \
    tar -xzf uv.tar.gz; \
    install -Dm755 "uv-${T}/uv"  /out/usr/local/bin/uv; \
    install -Dm755 "uv-${T}/uvx" /out/usr/local/bin/uvx

# bun — JS runtime / package runner
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) T=linux-x64 ;; \
      arm64) T=linux-aarch64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o bun.zip \
      "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-${T}.zip"; \
    unzip -q bun.zip; \
    install -Dm755 "bun-${T}/bun" /out/usr/local/bin/bun; \
    ln -s bun /out/usr/local/bin/bunx

# gdu — disk usage analyzer
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) T=linux_amd64_static ;; \
      arm64) T=linux_arm64_static ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o gdu.tgz \
      "https://github.com/dundee/gdu/releases/download/v${GDU_VERSION}/gdu_${T}.tgz"; \
    tar -xzf gdu.tgz; \
    install -Dm755 "gdu_${T}" /out/usr/local/bin/gdu

# yazi — terminal file manager
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) T=x86_64-unknown-linux-gnu ;; \
      arm64) T=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o yazi.zip \
      "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${T}.zip"; \
    unzip -q yazi.zip; \
    install -Dm755 "yazi-${T}/yazi" /out/usr/local/bin/yazi; \
    install -Dm755 "yazi-${T}/ya"   /out/usr/local/bin/ya

# zellij — modern terminal multiplexer
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) T=x86_64-unknown-linux-musl ;; \
      arm64) T=aarch64-unknown-linux-musl ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o zellij.tgz \
      "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${T}.tar.gz"; \
    tar -xzf zellij.tgz; \
    install -Dm755 zellij /out/usr/local/bin/zellij


# ============================================================
# Stage 2 — Final image
# ============================================================
FROM ${BASE_IMAGE}

ARG NODE_MAJOR=22
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

LABEL org.opencontainers.image.title="cluster-dev" \
      org.opencontainers.image.description="Deep-learning development environment for GPU clusters (CUDA + uv/bun/node + zellij/tmux + btop/gdu/yazi)" \
      org.opencontainers.image.licenses="MIT"

# ---- System packages (all under one cached layer) -------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        # Core
        ca-certificates curl wget gnupg sudo tzdata tini \
        # Build / dev
        build-essential pkg-config make cmake ninja-build \
        git git-lfs \
        # Editors / utilities
        vim nano less file zip unzip xz-utils bzip2 \
        # Networking
        openssh-client rsync \
        # Python (uv manages its own; this is for system scripts)
        python3 python3-venv python3-pip \
        # Shell + multiplexer + monitor
        zsh zsh-autosuggestions zsh-syntax-highlighting \
        tmux htop btop \
        # Quality-of-life CLIs
        jq ripgrep fd-find bat tree man-db \
 && rm -rf /var/lib/apt/lists/*

# Convenience symlinks (Ubuntu ships fd as fdfind, bat as batcat)
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ---- Node.js + npm (bun's fallback runtime) -------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    rm -rf /var/lib/apt/lists/*; \
    npm config set fund false --global; \
    npm config set update-notifier false --global

# ---- Pull binaries collected in the downloader stage ----------------------
COPY --from=downloader /out/ /

# ---- Non-root user (commonly remapped at runtime via `docker run --user`) -
# Ubuntu 24.04 ships a default `ubuntu` user/group at UID/GID 1000;
# remove it first so we can claim that UID for our `dev` user.
RUN if id ubuntu >/dev/null 2>&1;        then userdel --remove ubuntu 2>/dev/null || userdel ubuntu; fi \
 && if getent group ubuntu >/dev/null;   then groupdel ubuntu; fi \
 && groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /usr/bin/zsh ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# Make zsh the default login shell system-wide too (so `su -`, `sudo -i`, etc. land in zsh)
RUN chsh -s /usr/bin/zsh root

# ---- User dotfiles --------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} zshrc     /home/${USERNAME}/.zshrc
COPY --chown=${USERNAME}:${USERNAME} tmux.conf /home/${USERNAME}/.tmux.conf

# ---- Build-time sanity check (fails the build if any tool is broken) ------
RUN set -eux; \
    uv --version; uvx --version; \
    bun --version; test -x "$(command -v bunx)"; \
    node --version; npm --version; \
    btop --version; \
    gdu --version; \
    yazi --version; ya --version; \
    zellij --version; \
    tmux -V; \
    zsh --version

USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENV SHELL=/usr/bin/zsh

# tini as PID 1 → clean signal forwarding for interactive shells / training jobs
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["zsh", "-l"]
