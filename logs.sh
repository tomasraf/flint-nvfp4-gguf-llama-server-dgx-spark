#!/usr/bin/env bash
# logs.sh — Follow the llama.cpp server logs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
if [[ ! -f .env ]]; then
    echo "ERROR: .env not found."; exit 1
fi
source .env
CONTAINER_NAME="${CONTAINER_NAME:-llama-flint}"
shift $((OPTIND-1)) 2>/dev/null || true
docker logs -f "$CONTAINER_NAME" "$@"