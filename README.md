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

# Build and start the programming stack
docker compose up -d
```

The default remote-first stack includes LiteLLM, the VS Code workspace, Codex
CLI, Claude Code CLI, Qdrant, and SearXNG. LM Studio is disabled until a local
model is selected.

Set `CHUTES_API_KEY` and/or `OPENROUTER_API_KEY` in `.env` for the providers
you intend to use. No model ID is fixed at startup.

## Model selection

Use the root-level selector to choose the model for new Codex, Claude Code, and
VS Code Codex sessions:

```bash
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl use openrouter tencent/hy3:free
./modelctl use local openai/gpt-oss-20b
./modelctl list
```

Remote switches take effect immediately for new sessions. Any valid Chutes or
OpenRouter model ID can be selected; LiteLLM keeps the provider credentials in
the gateway. The selected provider/model is stored in `model-selection/` and is
also applied to the running agent containers without recreating them.

`./modelctl list` queries every provider's live model catalogue by default.
It keeps the provider rank, identifies the provider, and sorts rows by combined
input/output USD per million tokens, lowest first. Pass a provider or a count
(for example, `./modelctl list openrouter 20`) to narrow the list.

Selecting a local model starts the optional LM Studio service, downloads the
model when needed, unloads the previous local LLM, and loads the new one as
`local/model`. This can take time and should only be done after existing local
agent sessions have finished.

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
containers. Subsequent `modelctl` selections do not recreate containers.

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

## License
MIT
