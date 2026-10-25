#!/usr/bin/env bash
# ===========================================================================
# start.sh — Launch RecursiveSI/flint-nvfp4-gguf (llama.cpp server) on a
#            single DGX Spark.
#
# Runtime note: this GGUF is a custom "flint" architecture with packed NVFP4
# weights, supported only by llama.cpp. vLLM/SGLang cannot load it.
#
# Usage:
#   ./start.sh              # start (pulls image if missing)
#   ./start.sh --no-pull   # start using the already-pulled image
#   ./start.sh --no-download # skip model download if missing
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

info() { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m  $*"; exit 1; }

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------
if [[ ! -f .env ]]; then
    err "\".env\" not found — copy .env.sample to .env and edit it:"
fi
# shellcheck source=.env
source .env

# Expand a leading "~" so both "~/…" and full paths work (bash does not
# expand ~ inside variable values read back from .env)
FLINT_MODEL_DIR="${FLINT_MODEL_DIR/#\~/$HOME}"

# MODEL_FILE is computed from FLINT_MODEL_DIR + FLINT_FILE (not stored in .env)
MODEL_FILE="${FLINT_MODEL_DIR}/${FLINT_FILE}"

for var in FLINT_FILE FLINT_MODEL_DIR IMAGE CONTAINER_NAME HOST PORT CTX PARALLEL \
           N_GPU_LAYERS FAST_ATTN CACHE_K CACHE_V TEMP TOP_P TOP_K MIN_P \
           NVIDIA_LIB_DIR NVIDIA_DEVICES; do
    if [[ -z "${!var:-}" ]]; then
        err "Required variable $var is not set in .env"
    fi
done

# ---------------------------------------------------------------------------
# Parse CLI flags
# ---------------------------------------------------------------------------
DO_PULL=true
DO_DOWNLOAD=true
for arg in "$@"; do
    case "$arg" in
        --no-pull) DO_PULL=false ;;
        --no-download) DO_DOWNLOAD=false ;;
        -h|--help)
            sed -n '1,13p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) err "Unknown argument: $arg (try --help)" ;;
    esac
done

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
if [[ ! -f "$MODEL_FILE" ]]; then
    if $DO_DOWNLOAD; then
        info "Model file not found: $MODEL_FILE — downloading via ./download.sh ..."
        ./download.sh
    else
        err "Model file not found: $MODEL_FILE (run ./download.sh to fetch it)"
    fi
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    if $DO_PULL; then
        info "Image not present — pulling $IMAGE ..."
        docker pull "$IMAGE"
    else
        err "Image $IMAGE not found locally. Run ./start.sh (without --no-pull) to pull it."
    fi
fi

# ---------------------------------------------------------------------------
# Stop any previous instance
# ---------------------------------------------------------------------------
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    warn "Removing previous container $CONTAINER_NAME ..."
    docker rm -f "$CONTAINER_NAME" >/dev/null
fi

# ---------------------------------------------------------------------------
# Assemble device args (space-separated list from .env)
# ---------------------------------------------------------------------------
DEV_ARGS=()
for dev in $NVIDIA_DEVICES; do
    DEV_ARGS+=(--device "$dev")
done

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
info "Launching $CONTAINER_NAME ($IMAGE)"
info "  Model : $MODEL_FILE"
info "  API   : http://$HOST:$PORT/v1  (model id: flint)"

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    "${DEV_ARGS[@]}" \
    -v "$NVIDIA_LIB_DIR":/opt/drv:ro \
    -v "$(dirname "$MODEL_FILE")":/models:ro \
    -e LD_LIBRARY_PATH=/opt/drv \
    -p "$PORT":"$PORT" \
    --health-cmd "curl -sf http://localhost:$PORT/health" \
    --health-interval 15s \
    --health-timeout 5s \
    --health-retries 3 \
    "$IMAGE" \
    -m /models/"$(basename "$MODEL_FILE")" \
    --alias flint \
    -ngl "$N_GPU_LAYERS" \
    -c "$CTX" \
    -np "$PARALLEL" \
    -fa "$FAST_ATTN" \
    -ctk "$CACHE_K" \
    -ctv "$CACHE_V" \
    --jinja \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    --top-k "$TOP_K" \
    --min-p "$MIN_P" \
    --host "$HOST" \
    --port "$PORT" \
    $EXTRA_ARGS

ok "Container started. Waiting for the API to come up ..."

# ---------------------------------------------------------------------------
# Wait for /health
# ---------------------------------------------------------------------------
for _ in $(seq 1 120); do
    if curl -sf -m 3 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        ok "API ready: http://$HOST:$PORT/v1"
        echo "  Health: http://$HOST:$PORT/health"
        echo "  Logs:   docker logs -f $CONTAINER_NAME"
        exit 0
    fi
    sleep 2
done

err "Timed out waiting for the API. Check: docker logs -f $CONTAINER_NAME"
