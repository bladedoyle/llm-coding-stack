# local-llm-stack

A configurable, GPU-accelerated coding stack using Docker Compose.

## Features
- **LM Studio**: Configurable local model server with GPU acceleration.
- **LiteLLM**: OpenAI-compatible gateway for cloud-provider routing.
- **Chutes / Bittensor**: Optional cloud model pool available to the coding
  agents alongside the local model.
- **Codex CLI**: Autonomous coding agent for terminal-based tasks.
- **Claude Code CLI**: Anthropic's coding agent configured for the same model
  providers as Codex.
- **VS Code Workspace**: Pre-configured devcontainer with full toolchain and agents.
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

The stack includes LM Studio, LiteLLM, the VS Code workspace, Codex CLI,
Claude Code CLI, Qdrant, and SearXNG.

To enable the optional Chutes/Bittensor route, edit `.env` and replace
`CHUTES_API_KEY` with your `cpk_` key.

Set `CHUTES_MODEL` in `.env` to the exact Chutes model ID you want, for example
`deepseek-ai/DeepSeek-V3.2-TEE`. Codex routes through the local LiteLLM gateway,
which can log request and response payloads for local inspection.
The key is not stored in the repository or Docker images.

LM Studio runs one local prediction at a time. Each Chutes gateway route allows
up to five concurrent requests in LiteLLM.

Set `LLM_PROVIDER=chutes` to make Chutes the VS Code Codex plugin default, or
`LLM_PROVIDER=local` to use the model selected by `LOCAL_MODEL` instead. Set it to
`openrouter` to use the model selected by `OPENROUTER_MODEL` via OpenRouter.
The same selector configures Claude Code. Recreate the `workspace`, `codex`,
`claude-code`, and `lmstudio` services after changing the selector. Recreating
LM Studio loads the local LLM when `local` is selected or frees its GPU memory
when a remote provider is selected.

Use `LITELLM_DEBUG_MODE=off`, `debug`, or `detailed` in `.env` to control
LiteLLM gateway logging. Logging defaults to `off`; `detailed` logs may contain
prompt and tool data.

The Chutes Codex provider retries interrupted response streams up to 50 times.

OpenRouter is also available through LiteLLM as `openrouter/model`,
backed by the model selected with `OPENROUTER_MODEL` in `.env`. Set
`OPENROUTER_API_KEY` there before using it. The default model is
`tencent/hy3:free`.

Set `LOCAL_MODEL` to an LM Studio model key such as `openai/gpt-oss-20b` and
`LOCAL_CONTEXT_WINDOW` to the context length to allocate when loading it. LM
Studio exposes whichever model is selected through the stable `local/model`
identifier, so the coding clients do not need model-specific configuration.
Local traffic goes directly to LM Studio and is not routed through LiteLLM.
After changing either local setting, recreate only the model server:

```bash
docker compose up -d --force-recreate lmstudio
```

On first start, the `lmstudio` container will automatically pull the selected
model when `LLM_PROVIDER=local`. Chutes and OpenRouter selections skip both its
download and load. You can track progress with:
```bash
docker compose logs -f lmstudio
```

Note: The initial model pull can take a long time depending on your network speed.  The download only happens once on initial start. None of the tools will work before the model is downloaded.  Please be patient.

### 3. Usage
For detailed instructions on using the Codex and Claude Code CLIs or connecting
through VS Code, see [ACCESS.md](./ACCESS.md).

## Common Customizations

### Video Card Device
By default, the stack is configured to use all available NVIDIA GPUs. If you need to restrict it to specific devices, modify the `NVIDIA_VISIBLE_DEVICES` environment variable in `docker-compose.yml` for the `lmstudio` service:

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
