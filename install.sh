#!/bin/bash
DOTFILES="$HOME/.dotfiles"

# Helper: create symlink with backup
link() {
    local src="$1"
    local dest="$2"

    # Backup existing file if it's not already a symlink
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "Backing up $dest to $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    ln -sf "$src" "$dest"
    echo "Linked $dest -> $src"
}

# Detect current shell (bash or zsh)
current_shell=$(basename "$SHELL")

# Detect platform (Linux or Darwin/macOS)
platform=$(uname -s)

echo "Detected shell: $current_shell"
echo "Detected platform: $platform"
echo ""

# --all flag: install everything regardless of detection
install_all=false
if [[ "$1" == "--all" ]]; then
    install_all=true
    echo "Installing all configs (--all flag)"
    echo ""
fi

# Always install shared shell config
link "$DOTFILES/shell" "$HOME/.shell"

# Install shell-specific config based on detection (or all if --all)
if [[ "$install_all" == true || "$current_shell" == "bash" ]]; then
    link "$DOTFILES/bash/bashrc" "$HOME/.bashrc"
    link "$DOTFILES/bash/bash_profile" "$HOME/.bash_profile"
fi

if [[ "$install_all" == true || "$current_shell" == "zsh" ]]; then
    link "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"
    link "$DOTFILES/zsh/zprofile" "$HOME/.zprofile"
fi

echo ""
echo "Done! Restart your shell or run: source ~/.${current_shell}rc"
