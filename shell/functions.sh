# Common functions (sourced by both bash and zsh)

# Run Claude Code in a container
# Usage: claude [--no-firewall] [--image IMAGE_NAME] [-v|-volume HOST:CONTAINER[:OPTIONS] ...]
# Override default image: export CLAUDE_IMAGE="ghcr.io/luno33/claude-code:latest"
claude() {
    local no_firewall=false
    local extra_vol_flags=()

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

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-firewall)
                no_firewall=true
                shift
                ;;
            --image)
                image="$2"
                shift 2
                ;;
            -v|--volume)
                extra_vol_flags+=(-v "$2")
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Dynamic container name from current directory + TTY for uniqueness
    local dir_name=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
    local tty_id=$(tty | grep -o '[0-9]*$')
    local container_name="claude-code-${dir_name}-pts${tty_id}"
    local container_user="claude"
    local container_home="/home/$container_user"

    local user_flags=()
    if [[ "$runtime" == "podman" ]]; then
        CONTAINER_USER_ID=$(podman run --rm --entrypoint id claude-code:latest -u claude)
        CONTAINER_GROUP_ID=$(podman run --rm --entrypoint id claude-code:latest -g claude)

        user_flags=(
            --userns="keep-id:uid=${CONTAINER_USER_ID},gid=${CONTAINER_GROUP_ID}"
            --user "$container_user"
            -e "HOME=$container_home"
        )
    fi

    # Ensure required files and directories exist
    if [[ ! -d "$HOME/.claude-code/.claude" ]]; then
        mkdir -p "$HOME/.claude-code/.claude"
        printf "\033[33m > Created %s/.claude-code/.claude\033[0m\n" "$HOME"
    fi
    if [[ ! -f "$HOME/.claude-code/.claude.json" ]]; then
        echo "{}" > "$HOME/.claude-code/.claude.json"
        printf "\033[33m > Created %s/.claude-code/.claude.json\033[0m\n" "$HOME"
    fi
    if [[ ! -f "$HOME/.claude-code/firewall-whitelist.txt" ]]; then
        touch "$HOME/.claude-code/firewall-whitelist.txt"
        printf "\033[33m > Created %s/.claude-code/firewall-whitelist.txt\033[0m\n" "$HOME"
    fi
    if [[ ! -f "$HOME/.gitignore_global" ]]; then
        touch "$HOME/.gitignore_global"
        printf "\033[33m > Created %s/.gitignore_global\033[0m\n" "$HOME"
    fi

    # Firewall: caps and env var
    local cap_flags=()
    local firewall_env=()
    if [[ "$no_firewall" == false ]]; then
        cap_flags=(--cap-add=NET_ADMIN --cap-add=NET_RAW)
        printf "Setting up firewall for Claude Code...\n\n"
    else
        printf "\n\n\033[33m Disabling firewall for Claude Code, please be very careful and re-enable it as soon as possible.\033[0m\n\n"
        firewall_env=(-e DISABLE_FIREWALL=true)
    fi

    # Print container name for easy identification
    echo -e "\n\033[1;36m>>> Container name: \033[1;33m$container_name \033[1;36m <<<\033[0m\n"

    echo "Running Claude Code, the first startup might take few minutes..."

    $runtime run --rm -it \
        --name "$container_name" \
        "${cap_flags[@]}"  \
        "${firewall_env[@]}" \
        "${user_flags[@]}" \
        -v "$HOME/.gitignore_global":$container_home/.gitignore_global:ro \
        -v "$HOME/.claude-code/firewall-whitelist.txt":$container_home/.claude-code/firewall-whitelist.txt:ro \
        -v "$HOME/.claude-code/.claude":$container_home/.claude \
        -v "$HOME/.claude-code/.claude.json":$container_home/.claude.json \
        -v "$PWD":"$PWD" -w "$PWD" \
        "${extra_vol_flags[@]}" \
        "$image"
}

# Run llama.cpp server in a container
# Usage: llama-server [config-name]
#        llama-server add <name>
# Configs stored in: ~/.llama-cpp-configs/configs/*.conf
llama-server() {
    local config_dir="$HOME/.llama-cpp-configs"
    local configs_dir="$config_dir/configs"
    local cache_dir="$config_dir/cache"

    if [[ "$1" == "add" ]]; then
        mkdir -p "$configs_dir" "$cache_dir"
        local new_name="$2"
        if [[ -z "$new_name" ]]; then
            echo "Usage: llama-server add <config-name>"
            echo "Example: llama-server add qwen3-4b"
            return 1
        fi
        local new_file="$configs_dir/$new_name.conf"
        if [[ -f "$new_file" ]]; then
            echo "Config '$new_name' already exists: $new_file"
            return 1
        fi
        cat > "$new_file" << 'EOF'
# Llama.cpp Server Configuration
# Edit the MANDATORY fields below, then run: llama-server

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
# LLAMA_FLASH_ATTN=on     # flash attention (on/off)
# LLAMA_TEMPERATURE=0.6   # sampling temperature (0=greedy, higher=more random)
# LLAMA_TOP_P=0.95        # nucleus sampling threshold
# LLAMA_TOP_K=20          # top-k sampling (0=disabled)
# LLAMA_MIN_P=0.00        # minimum probability cutoff relative to top token
# LLAMA_PARALLEL=1        # number of parallel request slots
# LLAMA_CACHE_TYPE_K=q8_0 # KV cache quantization for keys (f16, q8_0, q4_0)
# LLAMA_CACHE_TYPE_V=q8_0 # KV cache quantization for values (f16, q8_0, q4_0)
# LLAMA_CACHE_RAM=4096    # max RAM in MB for prompt cache
# LLAMA_VERBOSE=true      # show layer placement (GPU vs CPU) and detailed load info
# === MTP / SPECULATIVE DECODING ===
# For Unsloth MTP GGUFs the draft heads are embedded — no separate model needed.
# LLAMA_SPEC_TYPE=draft-mtp  # draft-mtp for Unsloth/DeepSeek embedded heads
# LLAMA_SPEC_DRAFT_N_MAX=2   # max tokens to speculatively draft per step (1-4)
# LLAMA_SPEC_DRAFT_N_MIN=0   # min draft tokens before accepting
# LLAMA_SPEC_DRAFT_P_MIN=0.0 # min probability threshold to keep drafting
EOF
        echo "Created: $new_file"
        echo "Edit the config, then run: llama-server"
        return 0
    fi

    if [[ ! -d "$configs_dir" ]]; then
        mkdir -p "$configs_dir" "$cache_dir"
        echo "To create your first configuration, run: llama-server add <name>"
        echo "Example: llama-server add qwen3-4b"
        return 0
    fi

    # Find available configs
    local configs=()
    for f in "$configs_dir"/*.conf; do
        [[ -f "$f" ]] && configs+=("$(basename "$f" .conf)")
    done

    if [[ ${#configs[@]} -eq 0 ]]; then
        echo "No configs found in $configs_dir/"
        echo "To add a new configuration, run: llama-server add <name>"
        return 1
    fi

    # Select config: argument or interactive
    local config_name
    if [[ -n "$1" ]]; then
        config_name="$1"
        if [[ ! -f "$configs_dir/$config_name.conf" ]]; then
            echo "Config '$config_name' not found. Available: ${configs[*]}"
            echo "To add a new configuration, run: llama-server add <name>"
            return 1
        fi
    else
        printf "Commands:\n"
        printf "  llama-server <name>      skip this menu\n"
        printf "  llama-server add <name>  add new config\n\n"
        printf "Available configurations:\n"
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
    [[ -n "$LLAMA_TEMPERATURE" ]] && opt_args+=" --temp $LLAMA_TEMPERATURE"
    [[ -n "$LLAMA_TOP_P" ]] && opt_args+=" --top-p $LLAMA_TOP_P"
    [[ -n "$LLAMA_TOP_K" ]] && opt_args+=" --top-k $LLAMA_TOP_K"
    [[ -n "$LLAMA_MIN_P" ]] && opt_args+=" --min-p $LLAMA_MIN_P"
    [[ -n "$LLAMA_PARALLEL" ]] && opt_args+=" --parallel $LLAMA_PARALLEL"
    [[ -n "$LLAMA_CACHE_TYPE_K" ]] && opt_args+=" --cache-type-k $LLAMA_CACHE_TYPE_K"
    [[ -n "$LLAMA_CACHE_TYPE_V" ]] && opt_args+=" --cache-type-v $LLAMA_CACHE_TYPE_V"
    [[ -n "$LLAMA_CACHE_RAM" ]] && opt_args+=" --cache-ram $LLAMA_CACHE_RAM"
    [[ -n "$LLAMA_PRESENCE_PENALTY" ]] && opt_args+=" --presence-penalty $LLAMA_PRESENCE_PENALTY"
    [[ -n "$LLAMA_REPEAT_PENALTY" ]] && opt_args+=" --repeat-penalty $LLAMA_REPEAT_PENALTY"
    [[ -n "$LLAMA_FLASH_ATTN" ]] && opt_args+=" -fa $LLAMA_FLASH_ATTN"
    [[ -n "$LLAMA_SPEC_TYPE" ]] && opt_args+=" --spec-type $LLAMA_SPEC_TYPE"
    [[ -n "$LLAMA_SPEC_DRAFT_N_MAX" ]] && opt_args+=" --spec-draft-n-max $LLAMA_SPEC_DRAFT_N_MAX"
    [[ -n "$LLAMA_SPEC_DRAFT_N_MIN" ]] && opt_args+=" --spec-draft-n-min $LLAMA_SPEC_DRAFT_N_MIN"
    [[ -n "$LLAMA_SPEC_DRAFT_P_MIN" ]] && opt_args+=" --spec-draft-p-min $LLAMA_SPEC_DRAFT_P_MIN"
    [[ "${LLAMA_VERBOSE:-false}" == "true" ]] && opt_args+=" --verbose"
    
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
