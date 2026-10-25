#!/usr/bin/env bash
# stop.sh — Stop the Flint llama.cpp server container.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
if [[ ! -f .env ]]; then
    echo "ERROR: .env not found."; exit 1
fi
source .env
CONTAINER_NAME="${CONTAINER_NAME:-llama-flint}"
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 && echo "Stopped $CONTAINER_NAME." || echo "$CONTAINER_NAME not running."