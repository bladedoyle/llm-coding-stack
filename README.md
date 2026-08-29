# local-llm-stack

A configurable, GPU-accelerated coding stack using Docker Compose.

## Features
- **LM Studio**: Optional local model server that runs on CPU or NVIDIA GPUs.
- **LiteLLM**: OpenAI-compatible gateway with runtime provider/model routing.
- **Chutes / Bittensor**: Optional cloud model pool available to the coding
  agents alongside the local model.
- **Codex CLI**: Autonomous coding agent for terminal-based tasks.
- **Claude Code CLI**: Anthropic's coding agent configured for the same model
  providers as Codex.
- **VS Code Workspace**: Pre-configured devcontainer with full toolchain and agents.
- **Qdrant & SearXNG**: Vector memory and web search for agents.

## Getting Started

### 1. Prerequisites
- Docker and Docker Compose.
- NVIDIA Container Toolkit only when using local GPU inference.

### 2. Building and Running
```bash
# Clone the repository
git clone <repo-url>
cd local-llm-stack

# Create your local configuration
cp .env.example .env

# Generate a gateway key and paste it after LITELLM_MASTER_KEY= in .env
openssl rand -hex 32

# Build and start the programming stack
docker compose up -d
```

The default remote-first stack includes LiteLLM, the VS Code workspace, Codex
CLI, Claude Code CLI, Qdrant, and SearXNG. LM Studio is disabled until a local
model is selected.

Set `LITELLM_MASTER_KEY` to the generated value, then set `CHUTES_API_KEY`
and/or `OPENROUTER_API_KEY` for the providers you intend to use. Compose refuses
to start without the gateway key. No model ID is fixed at startup.

## Model selection

Use the root-level selector to choose the model for new Codex, Claude Code, and
VS Code Codex sessions:

```bash
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl use openrouter tencent/hy3:free
./modelctl use local openai/gpt-oss-20b
./modelctl use-local-coding
./modelctl use-local-coding-quality
./modelctl local stop
./modelctl list
```

Remote switches take effect immediately for new sessions. Any valid Chutes or
OpenRouter model ID can be selected; LiteLLM keeps the provider credentials in
the gateway. The selected provider/model is stored in `model-selection/` and is
also applied to the running agent containers without recreating them.

### Host applications

Host applications use LiteLLM at `http://localhost:4000/v1` with API key
`LITELLM_MASTER_KEY` from `.env`. Read `model-selection/selected.env` before
each new request or session to follow the current `modelctl` selection.

| Selected provider | Chat Completions model | Responses API model |
| --- | --- | --- |
| Chutes | `chutes/<MODEL_ID>` | `chutes-responses/<MODEL_ID>` |
| OpenRouter | `openrouter/<MODEL_ID>` | `openrouter/<MODEL_ID>` |
| Local | `local/model` | `local/model` |

There is no stable selected-model gateway alias. Applications should reread or
watch `model-selection/selected.env` to use subsequent model switches.

`./modelctl list` queries every provider's live model catalogue and shows
models costing up to $1 per million input-plus-output tokens by default. It
keeps the provider rank, identifies the provider, and sorts rows by combined
input/output USD per million tokens, lowest first. The Parameters column shows
the published parameter count when it is available. Pass `all` to remove the
price limit, or pass a provider or a count (for example, `./modelctl list
openrouter 20`) to narrow the list.

Selecting a local model starts the optional LM Studio service, downloads the
model when needed, unloads the previous local LLM, and loads the new one as
`local/model`. This can take time and should only be done after existing local
agent sessions have finished.

`./modelctl use-local-coding` is the NVIDIA coding preset. It recreates LM
Studio with a 32,768-token context and full GPU offload, downloads the pinned
gpt-oss-20b MXFP4 artifact when needed, and selects it as `local/model`.
Codex compacts local sessions at 24,576 tokens, reserving 8,192 tokens inside
the model's hard 32,768-token limit for request framing, tools, reasoning, and
output.

`./modelctl use-local-coding-quality` selects the measured gpt-oss-120b MXFP4
quality preset with six GPU layers split across both cards, the remaining
weights memory-mapped from host memory, and a project-managed swap file sized
so physical RAM plus usable swap equals 128 GiB. `./modelctl local stop`
unloads the model, stops LM Studio, and disables only that swap file while
retaining it for the next run. See `MODELS_RAM.md` for the measurements and
tradeoffs.

Local selections are persisted in `model-selection/lmstudio-startup.env`.
LM Studio uses `restart: unless-stopped` and automatically reloads that model
after a process or Docker daemon restart. After an intentional
`./modelctl local stop`, run the applicable preset again; the quality preset
must re-enable its project-managed swap before it can start.

On NVIDIA hosts, expose GPUs to LM Studio before selecting a local model:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml \
  ./modelctl use local openai/gpt-oss-20b
```

Without the NVIDIA override, local inference uses CPU and works on hosts that
do not have NVIDIA support. Set `LOCAL_GPU_OFFLOAD` in `.env` to control LM
Studio's CPU/GPU offload choice, and `LOCAL_CONTEXT_WINDOW` to set the local
context length.

Use `LITELLM_DEBUG_MODE=off`, `debug`, or `detailed` in `.env` to control
LiteLLM gateway logging. `detailed` logs may contain prompts, source code, and
tool data; keep them local.

### Updating an existing stack

Apply this change once by rebuilding and recreating the gateway and agent
containers. Add a generated `LITELLM_MASTER_KEY` to an existing `.env` first.
Subsequent `modelctl` selections do not recreate containers.

```bash
docker compose up -d --build --force-recreate litellm workspace codex claude-code
```

### 3. Usage
For detailed instructions on using the Codex and Claude Code CLIs or connecting
through VS Code, see [ACCESS.md](./ACCESS.md).

## Common Customizations

### Local GPU acceleration
Use `docker-compose.nvidia.yml` whenever starting or selecting the local
profile on an NVIDIA host. Set `NVIDIA_VISIBLE_DEVICES` in that override if you
need to restrict the exposed devices.

### Project Directory
The `vscode-workspace` container mounts a local directory for your code. By default, this is the `./workspaces` folder in the repository root, mapped to `/workspaces` inside the container.

To change which local folder is mapped into the workspace, update the volume mapping in `docker-compose.yml`:

```yaml
# In the workspace service:
volumes:
  - /path/to/your/actual/code:/workspaces
```

The agent containers are unprivileged and do not expose a host or nested Docker
daemon. Run Docker and Compose workflows from the host when they need to create
containers.

## License
MIT
