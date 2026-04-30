#!/usr/bin/env zsh
# Aliases and local conveniences.
# Adapted from chezmoi: dot_config/zsh/30-local.zsh + the previous cluster-dev zshrc.

alias ll='ls -alh --color=auto'
alias la='ls -A   --color=auto'
alias l='ls  -CF  --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

# CUDA on PATH (set by base image; reaffirm for safety on shells that miss it).
if [[ -d /usr/local/cuda/bin ]]; then
  export PATH="${CUDA_HOME:-/usr/local/cuda}/bin:${PATH}"
fi
