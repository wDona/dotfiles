# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Starship
export STARSHIP_CONFIG=~/.config/starship/starship.toml
eval "$(starship init zsh)"

# Zoxide (reemplaza cd)

# Thefuck
eval $(thefuck --alias)

# Carapace
source <(carapace _carapace zsh)

# fzf
source /usr/share/fzf/key-bindings.zsh

# Plugins
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6e6e6e"

# Autocompletado
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Aliases
alias ls='eza --icons'
alias ll='eza -la --icons'
alias cat='bat'

# Keybindings
bindkey '\t' autosuggest-accept
bindkey '^ ' expand-or-complete
setopt AUTO_MENU
export PATH="$HOME/.local/bin:$PATH"
export GOPATH="$HOME/Langs/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"

# Papelera recuperable (trash-cli) en vez de rm destructivo
alias trash='trash-put'
alias del='trash-put'
alias tl='trash-list'
alias tre='trash-restore'
alias te='trash-empty'

[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# zoxide init al FINAL del archivo (evita el warning del doctor)
eval "$(zoxide init zsh --cmd cd)"

export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

. "$HOME/.local/bin/env"

# lean-ctx shell hook — begin
if [ -f "$HOME/.config/lean-ctx/shell-hook.zsh" ]; then
. "$HOME/.config/lean-ctx/shell-hook.zsh"
fi
# lean-ctx shell hook — end

# >>> lean-ctx agent aliases >>>
alias claude='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" claude'
alias codebuddy='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" codebuddy'
alias codex='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" codex'
alias gemini='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" gemini'
# <<< lean-ctx agent aliases <<<
