# Common functions (sourced by both bash and zsh)

# Run Claude Code in a container
# Usage: claude [--image IMAGE_NAME]
# Override default image: export CLAUDE_IMAGE="ghcr.io/luno33/claude-code:latest"
claude() {
    # Detect container runtime (prefer podman)
    local runtime
    if command -v podman &>/dev/null; then
        runtime="podman"
    elif command -v docker &>/dev/null; then
        runtime="docker"
    else
        echo "Error: podman or docker required" >&2
        return 1
    fi

    # Image to use (override with CLAUDE_IMAGE env var or --image flag)
    # Local build: claude-code:latest
    # Remote:      ghcr.io/luno33/claude-code:latest
    local image="${CLAUDE_IMAGE:-claude-code:latest}"

    # Parse --image flag
    if [[ "$1" == "--image" && -n "$2" ]]; then
        image="$2"
        shift 2
    fi

    # Dynamic container name from current directory
    local dir_name=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
    local container_name="claude-code-${dir_name}"

    # Runtime-specific flags
    local user_flags=""
    if [[ "$runtime" == "podman" ]]; then
        user_flags="--userns=keep-id --user $(id -u):$(id -g)"
    fi

    # Run container
    $runtime run --rm -it \
        --name "$container_name" \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        $user_flags \
        -v "$HOME/.claude-code/.claude":/home/node/.claude \
        -v "$HOME/.claude-code/.claude.json":/home/node/.claude.json \
        -v "$PWD":/workspace -w /workspace \
        "$image" /bin/bash -c "sudo /usr/local/bin/init-firewall.sh && exec claude"
}

# Add your functions below
