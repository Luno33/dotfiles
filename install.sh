#!/bin/bash
DOTFILES="$HOME/.dotfiles"

# Parse flags
install_all=false
skip_confirm=false
for arg in "$@"; do
    case "$arg" in
        --all) install_all=true ;;
        -y|--yes) skip_confirm=true ;;
    esac
done

# Helper: create symlink with backup
link() {
    local src="$1"
    local dest="$2"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "Backing up $dest to $dest.backup"
        mv "$dest" "$dest.backup"
    fi

    ln -sfn "$src" "$dest"
    echo "Linked $dest -> $src"
}

# Detect current shell and platform
current_shell=$(basename "$SHELL")
platform=$(uname -s)

echo "Detected shell: $current_shell"
echo "Detected platform: $platform"
echo ""

# Build list of planned links
planned_src=()
planned_dest=()

plan_link() {
    planned_src+=("$1")
    planned_dest+=("$2")
}

# Always install shared shell config
plan_link "$DOTFILES/shell" "$HOME/.shell"

# Install shell-specific config based on detection (or all if --all)
if [[ "$install_all" == true || "$current_shell" == "bash" ]]; then
    plan_link "$DOTFILES/bash/bashrc" "$HOME/.bashrc"
    plan_link "$DOTFILES/bash/bash_profile" "$HOME/.bash_profile"
fi

if [[ "$install_all" == true || "$current_shell" == "zsh" ]]; then
    plan_link "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"
    plan_link "$DOTFILES/zsh/zprofile" "$HOME/.zprofile"
fi

# Show preview
echo "The following changes will be made:"
for i in "${!planned_dest[@]}"; do
    dest="${planned_dest[$i]}"
    src="${planned_src[$i]}"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "  $dest -> $src (backup: $dest.backup)"
    else
        echo "  $dest -> $src"
    fi
done
if [[ ! -e "$HOME/.gitignore_global" ]]; then
    echo "  $HOME/.gitignore_global <- $DOTFILES/git/gitignore_global (copy)"
else
    echo "  $HOME/.gitignore_global (exists, keeping)"
fi
echo ""

# Ask for confirmation (unless -y flag)
if [[ "$skip_confirm" == false ]]; then
    read -p "Proceed? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Execute links
for i in "${!planned_dest[@]}"; do
    link "${planned_src[$i]}" "${planned_dest[$i]}"
done

# Copy gitignore_global (only if doesn't exist, to preserve user's patterns)
if [[ ! -e "$HOME/.gitignore_global" ]]; then
    cp "$DOTFILES/git/gitignore_global" "$HOME/.gitignore_global"
    echo "Copied $HOME/.gitignore_global"
fi

# Configure git to use global gitignore
git config --global core.excludesfile "$HOME/.gitignore_global"
echo "Configured git global excludesfile"

echo ""
echo "Done! Restart your shell or run: source ~/.${current_shell}rc"
