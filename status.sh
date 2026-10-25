#!/usr/bin/env bash
# status.sh — Show container status, API health, GPU state.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
if [[ ! -f .env ]]; then
    echo "ERROR: .env not found."; exit 1
fi
source .env
CONTAINER_NAME="${CONTAINER_NAME:-llama-flint}"
PORT="${PORT:-8005}"
echo "--- container ---"
docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}  {{.Status}}  {{.Ports}}" || true
echo "--- health ---"
curl -s -m 5 "http://127.0.0.1:$PORT/health" || echo "no answer"
echo
echo "--- gpu ---"
nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null || true