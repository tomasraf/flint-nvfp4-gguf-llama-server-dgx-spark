#!/usr/bin/env bash
# ===========================================================================
# download.sh — Download the RecursiveSI/flint-nvfp4-gguf GGUF from Hugging Face
#              into FLINT_MODEL_DIR.
#
# Usage:
#   ./download.sh              # download the model (if not already present)
#   ./download.sh --no-download # skip download if already present
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

info() { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m  $*"; exit 1; }

if [[ ! -f .env ]]; then
    err "\".env\" not found — copy .env.sample to .env and edit it:"
fi
# shellcheck source=.env
source .env

REPO="${FLINT_REPO:-RecursiveSI/flint-nvfp4-gguf}"
FILE="${FLINT_FILE:-flint-nvfp4.gguf}"
LOCAL_DIR="${FLINT_MODEL_DIR:-~/models/RecursiveSI/flint-nvfp4-gguf}"
# Expand a leading "~" (bash does not expand ~ inside variable values)
LOCAL_DIR="${LOCAL_DIR/#\~/$HOME}"

DO_DOWNLOAD=true
for arg in "$@"; do
    case "$arg" in
        --no-download) DO_DOWNLOAD=false ;;
        -h|--help)
            sed -n '1,9p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) err "Unknown argument: $arg (try --help)" ;;
    esac
done

if $DO_DOWNLOAD; then
    mkdir -p "$LOCAL_DIR"
    info "Downloading $REPO ($FILE) -> $LOCAL_DIR ..."
    uvx --from huggingface_hub hf download "$REPO" "$FILE" --local-dir "$LOCAL_DIR"
    TARGET="$LOCAL_DIR/$FILE"
    [[ -f "$TARGET" ]] || err "Download finished but $TARGET is missing!"
    ok "Model ready: $TARGET"
else
    ok "Skipping download (--no-download)."
fi
