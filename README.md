# local-llm-stack

A configurable, GPU-accelerated local development stack using Docker Compose.
The programming environment runs by default; chat and voice services are
optional.

## Features
- **LM Studio**: Local model server (gpt-oss-20b) with GPU acceleration.
- **LiteLLM**: OpenAI-compatible gateway for multi-client routing.
- **Chutes / Bittensor**: Optional cloud model pool, available to Codex and
  Open WebUI alongside the local model.
- **Open WebUI**: Optional rich web interface for chat.
- **Codex CLI**: Autonomous coding agent for terminal-based tasks.
- **Claude Code CLI**: Anthropic's coding agent routed through the same local
  LiteLLM providers as Codex.
- **VS Code Workspace**: Pre-configured devcontainer with full toolchain and agents.
- **Kokoro TTS**: Optional high-quality local text-to-speech.
- **Qdrant & SearXNG**: Vector memory and web search for agents.

## Getting Started

### 1. Prerequisites
- NVIDIA GPU with 11GB or more
- Docker and Docker Compose.
- NVIDIA Container Toolkit (for GPU acceleration).
- [LM Studio](https://lmstudio.ai/) (optional, but the container handles model serving).

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

The default programming stack includes LM Studio, LiteLLM, the VS Code
workspace, Codex CLI, Claude Code CLI, Qdrant, and SearXNG. Select optional
non-programming components in `.env` with the comma-separated
`COMPOSE_PROFILES` setting:

```dotenv
# Programming stack only
COMPOSE_PROFILES=

# Add the browser chat interface
COMPOSE_PROFILES=webui

# Add browser chat and GPU text-to-speech
COMPOSE_PROFILES=webui,voice
```

The two optional profiles are independent. `voice` can be enabled without
`webui` when you only need Kokoro's API. If `webui` is enabled without `voice`,
chat and speech-to-text remain available, but text-to-speech is unavailable
until the `voice` profile is started.

You can override `.env` for a single command:

```bash
docker compose --profile webui up -d
docker compose --profile webui --profile voice up -d
```

Changing `COMPOSE_PROFILES` controls future starts but does not stop an
optional container that is already running. To apply a reduced selection,
stop the whole project (including every profile) and start it again:

```bash
docker compose --profile "*" down
docker compose up -d
```

To enable the optional Chutes/Bittensor route, edit `.env` and replace
`CHUTES_API_KEY` with your `cpk_` key.

Set `CHUTES_MODEL` in `.env` to the exact Chutes model ID you want, for example
`deepseek-ai/DeepSeek-V3.2-TEE`. Codex routes through the local LiteLLM gateway,
which is configured to log request and response payloads for local inspection.
Set `CHUTES_CONTEXT_WINDOW` there as well; `65536` is the default. The key is
not stored in the repository or Docker images.

LM Studio runs one local prediction at a time. Each Chutes gateway route allows
up to five concurrent requests in LiteLLM.

Set `LLM_PROVIDER=chutes` to make Chutes the VS Code Codex plugin default, or
`LLM_PROVIDER=local` to use LM Studio's `openai/gpt-oss-20b` instead. Set it to
`openrouter` to use the model selected by `OPENROUTER_MODEL` via OpenRouter.
The same selector configures Claude Code. Recreate the `workspace`, `codex`,
and `claude-code` services after changing the selector.

Use `LITELLM_DEBUG_MODE=off`, `debug`, or `detailed` in `.env` to control
LiteLLM gateway logging. `detailed` logs may contain prompt and tool data.

The Chutes Codex provider retries interrupted response streams up to 50 times.

OpenRouter is also available through LiteLLM as `openrouter/model`,
backed by the model selected with `OPENROUTER_MODEL` in `.env`. Set
`OPENROUTER_API_KEY` there before using it. The default model is
`tencent/hy3:free`; its OpenRouter Codex context default is
`OPENROUTER_CONTEXT_WINDOW=98304`.

On first start, the `lmstudio` container will automatically pull the
`gpt-oss-20b` model (~8-9 GB). You can track progress with:
```bash
docker compose logs -f lmstudio
```

Note: The initial model pull can take a long time depending on your network speed.  The download only happens once on initial start. None of the tools will work before the model is downloaded.  Please be patient.

### 3. Usage
For detailed instructions on how to access the Web UI, use the Codex CLI, or connect via VS Code, see [ACCESS.md](./ACCESS.md).

## Common Customizations

### Video Card Device
By default, the stack is configured to use all available NVIDIA GPUs. If you need to restrict it to specific devices, modify the `NVIDIA_VISIBLE_DEVICES` environment variable in `docker-compose.yml` for the `lmstudio` and `kokoro` services:

```yaml
environment:
  - NVIDIA_VISIBLE_DEVICES=0  # Use only the first GPU
```

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
