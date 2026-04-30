# syntax=docker.io/docker/dockerfile:1.7

# ============================================================
# cluster-dev — DL development image for GPU clusters
#
# Two build targets share a single CUDA base:
#   --target base  → minimal: CUDA + uv + bun
#   --target full  → base + node + btop / gdu / yazi / zellij + zsh + dotfiles
#
# CUDA base is the cudnn-devel variant for both targets, so the only
# difference between :base and :full is the dev-tooling layer on top.
# ============================================================

# ---- Base image ---------------------------------------------------------
ARG CUDA_VERSION=13.2.1
ARG UBUNTU_VERSION=24.04
ARG BASE_IMAGE=nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

# ---- Pinned upstream tool images (override with --build-arg) ------------
ARG UV_VERSION=0.11.8
ARG BUN_TAG=1-debian
ARG NODE_TAG=24-bookworm-slim

# ---- Pinned versions for tools fetched from GitHub releases -------------
ARG BTOP_VERSION=1.4.6
ARG GDU_VERSION=5.36.1
ARG YAZI_VERSION=26.1.22
ARG ZELLIJ_VERSION=0.44.1
ARG STARSHIP_VERSION=1.25.0


# ============================================================
# Source stages — pinned upstream official images we COPY from
# ============================================================
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv-src
FROM oven/bun:${BUN_TAG}                AS bun-src
FROM node:${NODE_TAG}                   AS node-src


# ============================================================
# Target: base — CUDA + uv + bun (and nothing else).
# ============================================================
FROM ${BASE_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

LABEL org.opencontainers.image.title="cluster-dev" \
      org.opencontainers.image.description="GPU dev image — CUDA cuDNN devel + uv + bun" \
      org.opencontainers.image.licenses="MIT"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# uv (Astral's official pattern: COPY from distroless image)
COPY --from=uv-src /uv /uvx /usr/local/bin/
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1

# bun (COPY from oven/bun:*-debian; glibc-compatible). Recreate bunx symlink.
COPY --from=bun-src /usr/local/bin/bun /usr/local/bin/bun
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx
ENV BUN_INSTALL=/usr/local

RUN set -eux; \
    uv --version; uvx --version; \
    bun --version; bunx --version

WORKDIR /workspace
CMD ["bash"]


# ============================================================
# Downloader stage — for tools without an official Docker image.
# Built once and consumed by the `full` target only.
# ============================================================
FROM debian:bookworm-slim AS downloader

ARG BTOP_VERSION
ARG GDU_VERSION
ARG YAZI_VERSION
ARG ZELLIJ_VERSION
ARG STARSHIP_VERSION
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl tar bzip2 unzip make \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/dl

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) RUST_TRIPLE_ARCH=x86_64; GO_ARCH=amd64 ;; \
      arm64) RUST_TRIPLE_ARCH=aarch64; GO_ARCH=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    printf 'export RUST_TRIPLE_ARCH=%s\nexport GO_ARCH=%s\n' \
      "$RUST_TRIPLE_ARCH" "$GO_ARCH" > /tmp/arch.env

# btop — upstream musl release (themes/assets included via `make install`)
RUN set -eux; . /tmp/arch.env; \
    curl -fsSL -o btop.tbz \
      "https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-${RUST_TRIPLE_ARCH}-unknown-linux-musl.tbz"; \
    tar -xjf btop.tbz; \
    cd btop && PREFIX=/out/usr/local make install

# gdu — single static binary
RUN set -eux; . /tmp/arch.env; \
    curl -fsSL -o gdu.tgz \
      "https://github.com/dundee/gdu/releases/download/v${GDU_VERSION}/gdu_linux_${GO_ARCH}_static.tgz"; \
    tar -xzf gdu.tgz; \
    install -Dm755 "gdu_linux_${GO_ARCH}_static" /out/usr/local/bin/gdu

# yazi — extract `yazi` and `ya` from musl zip
RUN set -eux; . /tmp/arch.env; \
    curl -fsSL -o yazi.zip \
      "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${RUST_TRIPLE_ARCH}-unknown-linux-musl.zip"; \
    mkdir -p /out/usr/local/bin; \
    unzip -j yazi.zip \
        "yazi-${RUST_TRIPLE_ARCH}-unknown-linux-musl/yazi" \
        "yazi-${RUST_TRIPLE_ARCH}-unknown-linux-musl/ya" \
        -d /out/usr/local/bin/; \
    chmod 0755 /out/usr/local/bin/yazi /out/usr/local/bin/ya

# zellij — single static musl binary
RUN set -eux; . /tmp/arch.env; \
    mkdir -p /out/usr/local/bin; \
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${RUST_TRIPLE_ARCH}-unknown-linux-musl.tar.gz" \
      | tar -xz -C /out/usr/local/bin zellij

# starship — official musl release
RUN set -eux; . /tmp/arch.env; \
    mkdir -p /out/usr/local/bin; \
    curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${RUST_TRIPLE_ARCH}-unknown-linux-musl.tar.gz" \
      | tar -xz -C /out/usr/local/bin starship

# Catppuccin theme assets (btop themes, bat themes) — pinned to head of `main`.
RUN set -eux; \
    mkdir -p /out/usr/local/share/btop/themes /out/usr/local/share/bat/themes; \
    curl -fsSL https://github.com/catppuccin/btop/archive/refs/heads/main.tar.gz | tar -xz -C /tmp; \
    cp /tmp/btop-main/themes/*.theme /out/usr/local/share/btop/themes/; \
    curl -fsSL https://github.com/catppuccin/bat/archive/refs/heads/main.tar.gz | tar -xz -C /tmp; \
    cp /tmp/bat-main/themes/*.tmTheme /out/usr/local/share/bat/themes/


# ============================================================
# Target: full — base + dev toolchain + dotfiles
# ============================================================
FROM base AS full

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.description="GPU dev image — CUDA cuDNN devel + uv/bun/node + zellij + btop/gdu/yazi/starship + zsh dotfiles"

# ---- System packages ----------------------------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg sudo tzdata tini \
        build-essential pkg-config make cmake ninja-build \
        git git-lfs \
        vim nano less file zip unzip xz-utils bzip2 \
        openssh-client rsync \
        python3 python3-venv python3-pip \
        zsh zsh-autosuggestions zsh-syntax-highlighting \
        tmux htop \
        jq ripgrep fd-find bat tree man-db \
        zoxide fzf \
 && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ---- Node.js + npm (COPY from node:24-bookworm-slim, recreate symlinks) -
COPY --from=node-src /usr/local/bin/node         /usr/local/bin/node
COPY --from=node-src /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN set -eux; \
    ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm; \
    ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx; \
    if [ -e /usr/local/lib/node_modules/corepack/dist/corepack.js ]; then \
        ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack; \
    fi; \
    npm config set fund false --global; \
    npm config set update-notifier false --global

# ---- Tools + theme assets from downloader stage ------------------------
COPY --from=downloader /out/usr/local/ /usr/local/

# ---- Non-root user (Ubuntu 24.04 ships `ubuntu` at UID 1000) -----------
RUN if id ubuntu >/dev/null 2>&1;        then userdel --remove ubuntu 2>/dev/null || userdel ubuntu; fi \
 && if getent group ubuntu >/dev/null;   then groupdel ubuntu; fi \
 && groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /usr/bin/zsh ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME} \
 && chsh -s /usr/bin/zsh root

# ---- Dotfiles (chezmoi-derived) ----------------------------------------
COPY --chown=${USERNAME}:${USERNAME} configs/zprofile        /home/${USERNAME}/.zprofile
COPY --chown=${USERNAME}:${USERNAME} configs/zshrc           /home/${USERNAME}/.zshrc
COPY --chown=${USERNAME}:${USERNAME} configs/zsh/            /home/${USERNAME}/.config/zsh/
COPY --chown=${USERNAME}:${USERNAME} configs/starship.toml   /home/${USERNAME}/.config/starship.toml
COPY --chown=${USERNAME}:${USERNAME} configs/btop.conf       /home/${USERNAME}/.config/btop/btop.conf
COPY --chown=${USERNAME}:${USERNAME} configs/bat.config      /home/${USERNAME}/.config/bat/config
COPY --chown=${USERNAME}:${USERNAME} configs/zellij.kdl      /home/${USERNAME}/.config/zellij/config.kdl

# Surface bat / btop theme assets in the user's per-tool config dir, so the
# theme names referenced in our configs resolve without extra setup.
RUN set -eux; \
    install -d -o ${USERNAME} -g ${USERNAME} \
        /home/${USERNAME}/.config/btop/themes \
        /home/${USERNAME}/.config/bat/themes; \
    cp /usr/local/share/btop/themes/*.theme /home/${USERNAME}/.config/btop/themes/; \
    cp /usr/local/share/bat/themes/*.tmTheme /home/${USERNAME}/.config/bat/themes/; \
    chown -R ${USERNAME}:${USERNAME} \
        /home/${USERNAME}/.config/btop/themes \
        /home/${USERNAME}/.config/bat/themes; \
    su ${USERNAME} -s /bin/bash -c 'bat cache --build' >/dev/null 2>&1 || true

# ---- Build-time sanity check (fails the build if any tool is broken) ---
RUN set -eux; \
    uv --version; uvx --version; \
    bun --version; test -x "$(command -v bunx)"; \
    node --version; npm --version; \
    btop --version; \
    gdu --version; \
    yazi --version; ya --version; \
    zellij --version; \
    starship --version; \
    zsh --version

USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENV SHELL=/usr/bin/zsh

# tini as PID 1 → clean signal forwarding for interactive shells / training.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["zsh", "-l"]
