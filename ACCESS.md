# Accessing the Stack

## Start / stop

```bash
docker compose up -d   # start the coding stack
docker compose down    # stop the stack (data preserved)
docker compose ps      # check status
```

## 1. Codex CLI — autonomous coding agent

```bash
docker compose exec codex bash -c "cd /workspaces/myProject; codex"
```

Select a model before starting a new session:
```bash
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl use openrouter tencent/hy3:free
./modelctl list
```

Non-interactive one-shot:
```bash
docker compose exec codex bash -c "cd /workspaces/myProject; codex exec --skip-git-repo-check \"your task here\""
```

List MCP servers:
```bash
docker compose exec codex codex mcp list
```

---

## 2. VS Code with Codex — IDE coding workspace

1. Open VS Code on the host.
2. Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`) if not already installed.
3. Press **F1** → `Dev Containers: Open Folder in Container` → select the `local-llm-stack` project root.
4. Choose the project to work on

VS Code attaches to the `vscode-workspace` container. The projects are at `/workspaces/*`.
Codex also works from the integrated terminal inside the container:
```bash
codex
```

The VS Code Codex plugin uses the same selection as the CLI. Run `./modelctl
use <provider> <model-id>`, then start a new agent session. If the current VS
Code agent does not pick up the new selection, reload the VS Code window; no
container recreation is needed.

---

## 3. Claude Code CLI

Claude Code uses the same selection as Codex and VS Code. Start it in a project
with:

```bash
docker compose exec claude-code bash -lc "cd /workspaces/myProject; claude"
```

For a non-interactive one-shot:

```bash
docker compose exec claude-code bash -lc \
  "cd /workspaces/myProject; claude -p 'your task here'"
```

For example, start the Claude workspace container, open a shell in it, and run
Claude Code against the included `hello_world` project:

```bash
docker compose up -d claude-code
docker compose exec claude-code bash
cd /workspaces/hello_world
claude
```

Projects under the host's `workspaces/` directory appear at `/workspaces` in
the container, so edits made during the session remain available on the host.

To select a local model, run:

```bash
./modelctl use local openai/gpt-oss-20b
```

For the researched NVIDIA coding setup (gpt-oss-20b MXFP4, 32K context, and
full GPU offload), use the single preset command:

```bash
./modelctl use-local-coding
```

Codex advertises the real 32K model maximum but compacts at 24,576 tokens to
reserve 8,192 tokens for protocol framing, tools, reasoning, and output.

This starts the optional LM Studio container, then downloads and loads the
model. It applies to new Claude sessions; do not switch while a local request is
in progress.

For the higher-quality RAM-offloaded gpt-oss-120b preset, use:

```bash
./modelctl use-local-coding-quality
```

It enables the project-managed swap file needed to simulate 128 GiB of total
physical-plus-swap capacity and loads the recorded 32K configuration with six
GPU layers split across both cards. Stop the local service and safely disable
only that swap file with `./modelctl local stop`. See `MODELS_RAM.md` for the
benchmark, memory-map explanation, and resource details.

The last local selection and its load settings are persisted. The LM Studio
container automatically restarts and reloads them after an unexpected process
exit or Docker daemon restart. An intentional `./modelctl local stop` disables
the quality preset's required swap; use the quality preset command to enable it
again before starting that model.

---

### Other services

## LiteLLM gateway
**http://localhost:4000** (localhost only)

```bash
# List available model aliases
curl http://localhost:4000/v1/models -H "Authorization: Bearer lm-studio" | jq .
```

LiteLLM accepts `chutes/<model-id>`, `chutes-responses/<model-id>`, and
`openrouter/<model-id>` routes. `modelctl` chooses the correct route for each
client API automatically. View request and response payloads after enabling
`detailed` logging with:
```bash
docker compose logs -f litellm
```
Those logs can include prompts, source code, tool output, and credentials in
tool arguments; keep them local and do not share them.

Set `LITELLM_DEBUG_MODE` in `.env` to `off`, `debug`, or `detailed`, then
recreate LiteLLM to apply it.

---

## LM Studio model server
**http://localhost:1234** (localhost only)

LM Studio is optional. `./modelctl use local <model-id>` starts it if needed,
then exposes the selected model as `local/model`. On an NVIDIA host, run the
selector with `COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml` to
expose GPUs; otherwise LM Studio runs on CPU.

On this host, `./modelctl use-local-coding` applies the recorded recommended
configuration without requiring those environment settings separately.
`./modelctl use-local-coding-quality` applies the separately researched
RAM-offloaded quality configuration.

```bash
# Check loaded models
curl http://localhost:1234/v1/models | jq .
```

---

## Qdrant vector DB — codebase RAG
**http://localhost:6333** (localhost only)

```bash
# Dashboard
open http://localhost:6333/dashboard
```

---

## SearXNG — web search
**http://localhost:8081** (localhost only)

Browser-accessible metasearch UI. Also queried automatically by the `searxng` MCP server during agent sessions.

---

## Persistent data

| What | Where |
|---|---|
| LM Studio models | `lmstudio_models` volume |
| Qdrant vectors | `qdrant_data` volume |
| Codex memory graph | `codex_cli_workspace_memory` volume |
| Workspace memory graph | `vscode_memory` volume |
| VS Code extensions / settings | `vscode_server` / `vscode_server_insiders` volumes |
| VS Code local data | `vscode_data` volume |
| Projects | `./workspaces/` (local mount) |
