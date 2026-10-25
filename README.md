# Flint NVFP4 GGUF — single-node launcher

Serves **RecursiveSI/flint-nvfp4-gguf** (`flint-nvfp4.gguf`, 22.9 GB — custom
`flint` architecture, packed NVFP4 weights) on one DGX Spark (192.168.36.90)
with the official llama.cpp `llama-server`, OpenAI-compatible API on port **8005**.

## Why llama.cpp and not vLLM/SGLang?

This GGUF uses a **custom `flint` architecture** with **packed NVFP4** weights.
* vLLM's GGUF loader only understands standard architectures (llama, qwen2,
  mistral, ...) and cannot map `general.architecture = flint`.
* SGLang has no GGUF path for this checkpoint either.
* The model card (RecursiveSI/flint-nvfp4-gguf) officially targets **llama.cpp
  with CUDA** and was tested on DGX Spark — so this recipe uses it.

The base BF16 repo (`RecursiveSI/flint`) ships an SGLang serving kit, but that
is a different ~80 GB download and not what this recipe serves.

## Files

| File             | Purpose                                             |
|------------------|-----------------------------------------------------|
| `.env.sample`    | Template config (copy to `.env`)                   |
| `start.sh`       | Launch the server (pulls image if needed)          |
| `stop.sh`        | Stop the container                                 |
| `status.sh`      | Container + /health + GPU state                   |
| `logs.sh`        | Follow server logs                                 |
| `docker-compose.yml` | Equivalent docker compose launcher             |
| `download.sh`       | Download the GGUF from Hugging Face            |

## Config — `.env`

The model path is **computed** from two variables in `.env`:

```bash
FLINT_FILE=flint-nvfp4.gguf
FLINT_MODEL_DIR=~/models/RecursiveSI/flint-nvfp4-gguf
```

`MODEL_FILE` is **not stored** in `.env` — it is derived as
`$FLINT_MODEL_DIR/$FLINT_FILE` (= `~/models/RecursiveSI/flint-nvfp4-gguf/flint-nvfp4.gguf`)
by `start.sh`, and `docker-compose.yml` interpolates `${FLINT_MODEL_DIR}` and
`${FLINT_FILE}` directly from `.env`.

Other key values: `PORT=8005`, `CONTAINER_NAME=llama-flint`,
`IMAGE=ghcr.io/ggml-org/llama.cpp:server-cuda13`.

## Start / stop

```bash
./download.sh       # download the GGUF from Hugging Face (if missing)
./start.sh          # start, waits for /health
./start.sh --no-pull  # skip docker pull
./stop.sh           # stop
./status.sh         # quick state
./logs.sh           # follow logs
```

Equivalent docker compose workflow:

```bash
docker compose up -d
docker compose logs -f
```

API: `http://192.168.36.90:8005/v1`  ·  health: `http://192.168.36.90:8005/health`
Served model id: `flint`  (OpenAI-compatible chat/completions, supports
`reasoning_content`).

Quick check:
```bash
curl http://127.0.0.1:8005/health
curl http://127.0.0.1:8005/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"flint","messages":[{"role":"user","content":"Hi!"}],"max_tokens":50}'
```

## Notes

* **GPU passthrough workaround.** `--gpus all` hits an NVIDIA container-toolkit
  bug here: the llama.cpp CUDA 13.4 image wants `libnvidia-egl-wayland.so.1.1.21`
  while the host driver 580.178.04 ships `.1.1.23`. The recipe passes the GPU
  devices explicitly and mounts the host lib dir **read-only** — the host is
  never modified.
* Context: 262 144 tokens by default; lower `CTX` in `.env` to trade KV memory
  for speed.
* `MODEL_FILE` is computed from `FLINT_MODEL_DIR` + `FLINT_FILE`; paths in
  `.env` use `~` (expanded by scripts; compose relies on `.env` interpolation).
* The running container (`llama-flint`, port 8005) mounts the model directory
  read-only and serves the OpenAI-compatible API on `http://192.168.36.90:8005/v1`.