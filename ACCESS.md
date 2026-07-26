# Accessing the Stack

## Start / stop

```bash
docker compose up -d       # start all services
docker compose down        # stop all (data volumes preserved)
docker compose ps          # check status
```

---

## 1. Open WebUI — chat-bot interface
Browser UI for chatting with the local model:

**http://localhost:3000**

---

## 2. Codex CLI — autonomous coding agent

```bash
docker compose exec codex bash -c "cd /workspaces/myProject; codex --profile lm-studio"
```

Use your Chutes/Bittensor model pool instead:
```bash
docker compose exec codex bash -c "cd /workspaces/myProject; codex --profile chutes"
```

Non-interactive one-shot:
```bash
docker compose exec codex bash -c "cd /workspaces/myProject; codex exec --profile lm-studio --skip-git-repo-check \"your task here\""
```

List MCP servers:
```bash
docker compose exec codex codex mcp list
```

---

## 3. VS Code with Codex — IDE coding workspace

1. Open VS Code on the host.
2. Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`) if not already installed.
3. Press **F1** → `Dev Containers: Open Folder in Container` → select the `local-llm-stack` project root.
4. Choose the project to work on

VS Code attaches to the `vscode-workspace` container. The projects are at `/workspaces/*`.
Codex also works from the integrated terminal inside the container:
```bash
codex --profile lm-studio
```

The VS Code Codex plugin defaults to the `CHUTES_MODEL` configured in `.env`,
routed through LiteLLM and Chutes. For the terminal, run
`codex --profile chutes`.

---

## 4. Claude Code CLI

Claude Code uses the same `LLM_PROVIDER` value as Codex and VS Code:
`chutes`, `local`, or `openrouter`. Start it in a project with:

```bash
docker compose exec claude-code bash -lc "cd /workspaces/myProject; claude"
```

For a non-interactive one-shot:

```bash
docker compose exec claude-code bash -lc \
  "cd /workspaces/myProject; claude -p 'your task here'"
```

Claude Code sends Anthropic Messages API requests to LiteLLM at
`http://litellm:4000`, which maps the selected provider to the same stable model
aliases used elsewhere in the stack. After changing `LLM_PROVIDER`, recreate
only this CLI container to apply its new default:

```bash
docker compose up -d --force-recreate --no-deps claude-code
```

---

### Other services

## LiteLLM gateway
**http://localhost:4000** (localhost only)

```bash
# List available model aliases
curl http://localhost:4000/v1/models -H "Authorization: Bearer lm-studio" | jq .
```

Chutes is exposed as `chutes/model`. Select that model in Open WebUI
after adding your Chutes key to `.env` and restarting LiteLLM.

The model selected by `OPENROUTER_MODEL` is exposed as the stable
`openrouter/model` route. Set `OPENROUTER_MODEL` and
`OPENROUTER_API_KEY` in `.env`, then restart LiteLLM before selecting it in
Open WebUI.

Use it with Codex from a terminal via `codex --profile openrouter`. To make it
the VS Code Codex plugin default, set `LLM_PROVIDER=openrouter` in `.env` before
recreating the workspace.

Codex Responses-API traffic is routed as `chutes/model-responses`. View its
request and response payloads with:
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

## Kokoro TTS
**http://localhost:8880** (localhost only)

Used automatically by Open WebUI for text-to-speech. No direct interaction needed.

---

## Persistent data

| What | Where |
|---|---|
| LM Studio models | `lmstudio_models` volume |
| Open WebUI chats / settings | `webui_data` volume |
| Qdrant vectors | `qdrant_data` volume |
| Codex memory graph | `codex_cli_workspace_memory` volume |
| Workspace memory graph | `vscode_memory` volume |
| VS Code extensions / settings | `vscode_server` / `vscode_server_insiders` volumes |
| VS Code local data | `vscode_data` volume |
| Projects | `./workspaces/` (local mount) |
