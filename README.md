# local-llm-stack

A Docker Compose development stack for running Codex CLI, Claude Code, and the
Codex VS Code extension against either cloud models or an optional local LM
Studio server.

## Services

| Service | Purpose | Default | Host access |
| --- | --- | --- | --- |
| LiteLLM | Model gateway | Yes | `127.0.0.1:4000` |
| Workspace | VS Code dev container | Yes | Dev Containers |
| Codex | CLI agent | Yes | `docker compose exec codex` |
| Claude Code | CLI agent | Yes | `docker compose exec claude-code` |
| Qdrant | Vector database | Yes | `127.0.0.1:6333` |
| SearXNG | Search engine | Yes | `127.0.0.1:8081` |
| LM Studio | Local model server | `local` only | `127.0.0.1:1234` |

All published ports bind to loopback. The default stack does not expose an API
to other hosts.

## Requirements

- Docker Engine and Docker Compose v2.
- Bash, `curl`, `jq`, OpenSSL, and standard Linux command-line tools for
  `modelctl` and initial setup.
- An NVIDIA driver and NVIDIA Container Toolkit for either NVIDIA coding
  preset.
- Enough disk space for downloaded local models. Set `HF_TOKEN` when a model
  requires authentication or higher Hugging Face download limits.
- Passwordless or interactive `sudo` access on the host for the 120B quality
  preset's managed swap file.

Generic local models can run without the NVIDIA override. Their practical CPU,
RAM, disk, and GPU requirements depend on the selected model and quantization.

## Quick start

```bash
git clone <repo-url>
cd local-llm-stack
cp .env.example .env
openssl rand -hex 32
```

Paste the generated value after `LITELLM_MASTER_KEY=` in `.env`. Compose refuses
to render the stack without this key. Replace the Chutes and OpenRouter
placeholders for the providers you plan to use; at least one working provider
key is needed for remote inference.

Build and start the default stack:

```bash
docker compose up -d --build
docker compose ps
```

The default provider and model come from `DEFAULT_MODEL_PROVIDER` and
`DEFAULT_MODEL` until a selection is written under `model-selection/`.
You can omit the cloud-provider keys when the stack will only use local
inference.

## Model selection

Run the root-level `modelctl` from the host. It updates the shared selection
and applies it to running agent containers. Start a new Codex or Claude session
after switching models.

```bash
# Remote providers
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl use openrouter tencent/hy3:free

# Generic local model
./modelctl use local openai/gpt-oss-20b

# Host-tuned NVIDIA presets
./modelctl use-local-coding
./modelctl use-local-coding-quality

# Inspect or stop
./modelctl current
./modelctl local list
./modelctl local stop
```

The client route depends on the selected provider:

| Provider | Codex Responses route | Claude/chat route |
| --- | --- | --- |
| Chutes | `chutes-responses/<MODEL_ID>` | `chutes/<MODEL_ID>` |
| OpenRouter | `openrouter/<MODEL_ID>` | `openrouter/<MODEL_ID>` |
| Local | `local/model` | `local/model` |

There is no gateway alias for "the currently selected remote model." Host
applications that follow `modelctl` should read
`model-selection/selected.env` before opening a session and use the route from
the table above.

Selecting Chutes or OpenRouter does not stop an already running LM Studio
container. Run `./modelctl local stop` when you want to release its CPU, GPU,
RAM, and managed-swap resources. That stop command does not change the selected
route, so select a remote model as well when moving away from local inference.

### Browse remote models

`modelctl list` reads the live Chutes and OpenRouter catalogues. Results retain
each provider's published rank and are sorted by combined input/output price.
The default view includes models costing at most $1 per million combined
tokens.

```bash
./modelctl list
./modelctl list 20
./modelctl list chutes all
./modelctl list openrouter 20
```

Use `all` to remove the price ceiling. Local models are not included because
their cost is host-specific.

## Local inference

Selecting a generic local model starts the `local` profile, downloads the model
through LM Studio when necessary, and exposes it as `local/model`. The default
Compose file is CPU-compatible. To expose NVIDIA GPUs for a generic selection:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml \
  ./modelctl use local openai/gpt-oss-20b
```

`LOCAL_CONTEXT_WINDOW` and `LOCAL_GPU_OFFLOAD` in `.env` control generic local
selections. `HF_TOKEN` is passed only to LM Studio and is optional for public
models that permit anonymous downloads.

### NVIDIA coding preset

```bash
./modelctl use-local-coding
```

This preset automatically uses `docker-compose.nvidia.yml`, downloads
`lmstudio-community/gpt-oss-20b-GGUF` at MXFP4 when needed, sets a 32,768-token
context, and requests full GPU offload. Codex compacts at 24,576 tokens so
8,192 tokens remain for framing, tools, reasoning, and output.

### NVIDIA quality preset

```bash
./modelctl use-local-coding-quality
```

This is a host-tuned `ggml-org/gpt-oss-120b-GGUF` MXFP4 configuration. It uses
a 32,768-token context, six GPU layers, and a hard-coded two-GPU tensor split.
Review `lmstudio-entrypoint.sh` before using it on different GPU hardware.

The preset also:

- requires the repository to be on ext4;
- creates `.modelctl.swap` so physical RAM plus usable project swap totals
  128 GiB;
- requires enough disk for that swap file, the model, and a 1 GiB free-space
  safety margin;
- verifies at least 2 GiB of host memory and 512 MiB on each GPU remain after
  loading; and
- stops LM Studio and disables the project swap if selection fails or is
  interrupted.

The swap file is retained for reuse but ignored by Git. Stop local inference
with the following command before `docker compose down` when the quality preset
is active:

```bash
./modelctl local stop
```

That command unloads local models, stops LM Studio, and disables only the
project-managed swap file.

### Persistence and restarts

Local model files live in the `lmstudio_models` named volume. Load settings are
stored in `model-selection/lmstudio-startup.env`. LM Studio uses
`restart: unless-stopped` and reloads the saved local selection after an
unexpected process or Docker daemon restart. After an intentional
`modelctl local stop`, run the applicable selection command again; the quality
preset must re-enable swap before it starts.

The LM Studio image pins llmster and its CUDA backend, verifies their download
checksums during build, and exposes the matching bundled CUDA runtime libraries
to the backend.

## Configuration map

| Path | Role |
| --- | --- |
| `.env` | Local credentials, default model, logging, and generic local-model settings |
| `docker-compose.yml` | Default services, mounts, health checks, and loopback ports |
| `docker-compose.nvidia.yml` | NVIDIA GPU exposure for LM Studio |
| `litellm_config.yaml` | Cloud, local LLM, and local embedding gateway routes |
| `modelctl` | Host-side selection, local-model lifecycle, and remote model catalogue |
| `model-selection/` | Runtime selection and LM Studio restart state shared with containers |

## Accessing the agents and APIs

See [ACCESS.md](./ACCESS.md) for interactive and one-shot Codex and Claude
commands, VS Code attachment, API examples, MCP services, and persistent data.

## Security model

- LiteLLM is the only service that receives Chutes and OpenRouter credentials.
  Agents receive the separate `LITELLM_MASTER_KEY` used to authenticate to the
  gateway.
- LiteLLM, LM Studio, Qdrant, and SearXNG publish only loopback ports.
- Workspace, Codex, and Claude Code run as UID 1000 in unprivileged containers.
  They do not receive a Docker socket, Docker CLI, nested daemon, or privileged
  container access.
- Codex and Claude are configured to skip their internal approval prompts
  because Docker is the execution boundary. They have passwordless `sudo`
  inside their containers, outbound network access, and write access to the
  mounted `./workspaces` directory. Treat everything in that directory as
  writable by the agents.
- `LITELLM_DEBUG_MODE=detailed` can log prompts, source code, tool output, and
  request data. Keep detailed logs local and enable them only when needed.

## Projects and persistent data

Host projects under `./workspaces` are mounted at `/workspaces` in all three
agent containers. Change the corresponding volume entries in
`docker-compose.yml` if projects live elsewhere.

Named volumes retain LM Studio models, Qdrant data, agent memory, Claude's home
directory, and VS Code server state. `docker compose down` preserves them;
`docker compose down -v` deletes them.

Run Docker and Compose workflows from the host. The agent containers
intentionally have no Docker client or daemon access.

## Updating the stack

Rebuild and recreate the locally built services after pulling changes:

```bash
docker compose up -d --build --force-recreate workspace codex claude-code litellm
```

If the optional local image changed, rebuild it separately without starting a
saved model:

```bash
docker compose build lmstudio
```

## License

MIT
