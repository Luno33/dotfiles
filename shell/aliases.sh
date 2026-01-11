# Common aliases (sourced by both bash and zsh)

# Navigation
alias ..="cd .."
alias ...="cd ../.."

# List files
alias ll="ls -lah"
alias la="ls -A"

# Safety prompts
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"

# Git
alias gitlog='git log --all --graph --oneline --format="%C(yellow)%h %C(bold blue)%an %C(green)%ad %C(yellow)%d %C(reset)%s" --date=relative'
alias gittag='git tag --sort=-creatordate --format="%(color:yellow)%(refname:short)%(color:reset) - %(color:green)%(creatordate:short)%(color:reset) - %(color:bold blue)%(taggername)%(color:reset) - %(contents:subject)"'

# Add your aliases below
