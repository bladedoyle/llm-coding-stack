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

---

### Other services

## LiteLLM gateway
**http://localhost:4000** (localhost only)

```bash
# List available model aliases
curl http://localhost:4000/v1/models -H "Authorization: Bearer lm-studio" | jq .
```

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
