#!/usr/bin/env zsh
# Core shell options + XDG paths + history.
# Adapted from chezmoi: dot_config/zsh/10-base.zsh.

typeset -U path PATH fpath FPATH

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME}/zsh"
export ZSH_COMPDUMP="${ZSH_CACHE_DIR}/zcompdump-${HOST}-${ZSH_VERSION}"
export LESSHISTFILE=-

mkdir -p "$ZSH_CACHE_DIR" "$ZSH_CACHE_DIR/completion"

setopt auto_cd
setopt auto_menu
setopt complete_in_word
setopt no_beep
setopt prompt_subst
setopt pushdminus

WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

export HISTFILE="${HOME}/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000

setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt inc_append_history
setopt share_history

# Emacs key bindings (Ctrl-a / Ctrl-e / etc.)
bindkey -e

autoload -Uz compinit && compinit -d "$ZSH_COMPDUMP"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' '+r:|[._-]=* r:|=*'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
