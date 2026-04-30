#!/usr/bin/env zsh
# Tool integrations: starship, uv, bun, npm, zoxide, fzf, syntax-highlighting, autosuggestions.

# --- bun ------------------------------------------------------------------
export BUN_INSTALL="${BUN_INSTALL:-/usr/local}"
[[ -d "$BUN_INSTALL/bin" ]] && path=("$BUN_INSTALL/bin" $path)

# --- npm (no-sudo global installs) ---------------------------------------
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
[[ -d "${NPM_CONFIG_PREFIX}/bin" ]] && path=("${NPM_CONFIG_PREFIX}/bin" $path)

# --- uv shell completion -------------------------------------------------
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh 2>/dev/null)"
fi

# --- zoxide --------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# --- fzf -----------------------------------------------------------------
if [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi
if [[ -r /usr/share/doc/fzf/examples/completion.zsh ]]; then
  source /usr/share/doc/fzf/examples/completion.zsh
fi

# --- zsh autosuggestions / syntax-highlighting (apt packages) -----------
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# syntax-highlighting must be sourced LAST among interactive plugins.
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- starship prompt -----------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
