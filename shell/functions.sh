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

    # Mount global gitignore if it exists
    local gitignore_mount=""
    if [[ -f "$HOME/.gitignore_global" ]]; then
        gitignore_mount="-v $HOME/.gitignore_global:/home/node/.gitignore_global:ro"
    fi

    # Run container
    $runtime run --rm -it \
        --name "$container_name" \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        $user_flags \
        $gitignore_mount \
        -v "$HOME/.claude-code/.claude":/home/node/.claude \
        -v "$HOME/.claude-code/.claude.json":/home/node/.claude.json \
        -v "$PWD":/workspace -w /workspace \
        "$image" /bin/bash -c "[ -f ~/.gitignore_global ] && git config --global core.excludesfile ~/.gitignore_global; sudo /usr/local/bin/init-firewall.sh && exec claude"
}

# Run llama.cpp server in a container
# Usage: llama-server [config-name]
# Configs stored in: ~/.llama-cpp-configs/configs/*.conf
llama-server() {
    local config_dir="$HOME/.llama-cpp-configs"
    local configs_dir="$config_dir/configs"
    local cache_dir="$config_dir/cache"

    # Bootstrap: create directory structure and template on first run
    if [[ ! -d "$configs_dir" ]]; then
        echo "First run: creating config directory structure..."
        mkdir -p "$configs_dir" "$cache_dir"
        cat > "$configs_dir/example.conf.template" << 'EOF'
# Llama.cpp Server Configuration
# Rename to <name>.conf (e.g., qwen3-4b.conf)
# Run: llama-server <name>  (or just: llama-server for interactive selection)

# === MANDATORY ===
LLAMA_MODEL="/path/to/your/models/your-model.gguf"
LLAMA_RUNTIME="podman"    # "docker" (for GPU) or "podman"

# === OPTIONAL (uncomment to override llama.cpp defaults) ===
# LLAMA_PORT=8080         # default: 8080
# LLAMA_THREADS=8         # default: auto-detect
# LLAMA_CONTEXT=4096      # default: 2048
# LLAMA_PREDICT=512       # default: -1 (unlimited)
# LLAMA_GPU_LAYERS=0      # default: 0 (CPU only), -1=all GPU, N=hybrid
# LLAMA_SUDO=true         # default: false (prepend sudo to docker commands)
# LLAMA_IMAGE="ghcr.io/ggml-org/llama.cpp:server"  # default (CPU). GPU options:
#   ghcr.io/ggml-org/llama.cpp:server-cuda   (NVIDIA)
#   ghcr.io/ggml-org/llama.cpp:server-rocm   (AMD)
#   ghcr.io/ggml-org/llama.cpp:server-vulkan (cross-platform GPU)
#   ghcr.io/ggml-org/llama.cpp:server-intel  (Intel oneAPI)
#   ghcr.io/ggml-org/llama.cpp:server-musa   (Moore Threads)
EOF
        echo "Created: $configs_dir/example.conf.template"
        echo "Edit the template, rename to <name>.conf, then run: llama-server <name>"
        return 0
    fi

    # Find available configs
    local configs=()
    for f in "$configs_dir"/*.conf; do
        [[ -f "$f" ]] && configs+=("$(basename "$f" .conf)")
    done

    if [[ ${#configs[@]} -eq 0 ]]; then
        echo "No configs found in $configs_dir/"
        echo "Create a .conf file based on example.conf.template"
        return 1
    fi

    # Select config: argument or interactive
    local config_name
    if [[ -n "$1" ]]; then
        config_name="$1"
        if [[ ! -f "$configs_dir/$config_name.conf" ]]; then
            echo "Config '$config_name' not found. Available: ${configs[*]}"
            return 1
        fi
    else
        echo "Available configurations:"
        select config_name in "${configs[@]}"; do
            [[ -n "$config_name" ]] && break
        done
    fi

    # Source config
    source "$configs_dir/$config_name.conf"

    # Validate required fields
    if [[ ! -f "$LLAMA_MODEL" ]]; then
        echo "Error: Model not found: $LLAMA_MODEL" >&2
        return 1
    fi
    model_dir=$(dirname "$LLAMA_MODEL")

    # Validate runtime
    local runtime="$LLAMA_RUNTIME"
    if [[ "$runtime" != "docker" && "$runtime" != "podman" ]]; then
        echo "Error: LLAMA_RUNTIME must be 'docker' or 'podman'" >&2
        return 1
    fi
    if ! command -v "$runtime" &>/dev/null; then
        echo "Error: $runtime not installed" >&2
        return 1
    fi

    # GPU flags (docker only, when GPU layers requested)
    local gpu_flags=""
    if [[ "$runtime" == "docker" && -n "$LLAMA_GPU_LAYERS" && "$LLAMA_GPU_LAYERS" != "0" ]]; then
        gpu_flags="--gpus all"
    fi

    # Sudo prefix (for docker without user in docker group)
    local sudo_prefix=""
    if [[ "${LLAMA_SUDO:-false}" == "true" ]]; then
        sudo_prefix="sudo"
    fi

    # Build optional llama.cpp args
    local opt_args=""
    [[ -n "$LLAMA_PORT" ]] && opt_args+=" --port $LLAMA_PORT"
    [[ -n "$LLAMA_THREADS" ]] && opt_args+=" --threads $LLAMA_THREADS"
    [[ -n "$LLAMA_CONTEXT" ]] && opt_args+=" --ctx-size $LLAMA_CONTEXT"
    [[ -n "$LLAMA_PREDICT" ]] && opt_args+=" --predict $LLAMA_PREDICT"
    [[ -n "$LLAMA_GPU_LAYERS" ]] && opt_args+=" --gpu-layers $LLAMA_GPU_LAYERS"

    local port="${LLAMA_PORT:-8080}"
    local image="${LLAMA_IMAGE:-ghcr.io/ggml-org/llama.cpp:server}"

    echo "Starting $config_name on port $port..."

    # Build and run container command
    local cmd="$sudo_prefix $runtime run --rm -it \
        $gpu_flags \
        -p $port:$port \
        -v $cache_dir:/root/.cache \
        -v $model_dir:/models:ro \
        $image \
        -m /models/$(basename "$LLAMA_MODEL") \
        --host 0.0.0.0 $opt_args \
        --jinja"

    echo "$cmd"
    eval "$cmd"
}

# Add your functions below
