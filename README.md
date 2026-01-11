# Dotfiles

Minimal, easy-to-read dotfiles for bash and zsh.

## Install

```bash
git clone https://github.com/Luno33/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The install script auto-detects your shell and only installs relevant config.
Use `--all` to install everything: `~/.dotfiles/install.sh --all`

## Structure

```
dotfiles/
├── shell/          # Shared config (sourced by both bash and zsh)
│   ├── aliases.sh
│   ├── functions.sh
│   └── exports.sh
├── bash/           # Bash-specific config
│   ├── bashrc
│   └── bash_profile
└── zsh/            # Zsh-specific config
    ├── zshrc
    └── zprofile
```

## Customizing

- Add aliases to `shell/aliases.sh`
- Add functions to `shell/functions.sh`
- Add environment variables to `shell/exports.sh`
- Add shell-specific settings to `bash/bashrc` or `zsh/zshrc`
