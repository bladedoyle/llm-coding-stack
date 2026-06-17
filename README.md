# local-llm-stack

A complete, GPU-accelerated local development stack using Docker Compose. This project provides a private LLM environment for chatting and autonomous coding agents.

## Features
- **LM Studio**: Local model server (gpt-oss-20b) with GPU acceleration.
- **LiteLLM**: OpenAI-compatible gateway for multi-client routing.
- **Open WebUI**: Rich web interface for chat.
- **Codex CLI**: Autonomous coding agent for terminal-based tasks.
- **VS Code Workspace**: Pre-configured devcontainer with full toolchain and agents.
- **Kokoro TTS**: High-quality local text-to-speech.
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

# Build and start all services
docker compose up -d
```

On first start, the `lmstudio` container will automatically pull the `gpt-oss-20b` model (~8-9 GB). You can track progress with:
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
