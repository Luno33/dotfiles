# Dotfiles

Minimal, easy-to-read dotfiles for bash and zsh.

## Install

```bash
git clone https://github.com/Luno33/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The install script auto-detects your shell, shows a preview of changes, and asks for confirmation.

Flags:
- `--all` - Install config for all shells (not just the detected one)
- `-y` - Skip confirmation prompt

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
├── zsh/            # Zsh-specific config
│   ├── zshrc
│   └── zprofile
└── git/            # Git config
    └── gitignore_global
```

## Customizing

- Add aliases to `shell/aliases.sh`
- Add functions to `shell/functions.sh`
- Add environment variables to `shell/exports.sh`
- Add shell-specific settings to `bash/bashrc` or `zsh/zshrc`
