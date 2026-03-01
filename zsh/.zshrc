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
eval "$(zoxide init zsh --cmd cd)"
