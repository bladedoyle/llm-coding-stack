# Accessing the stack

Complete the setup in [README.md](./README.md) first. Commands in this document
run from the repository root unless noted otherwise.

## Start, inspect, and stop

```bash
docker compose up -d
docker compose ps
docker compose logs -f --tail 100
```

The default command starts LiteLLM, Qdrant, SearXNG, and the three agent
containers. LM Studio starts only when selected through `modelctl` or when the
`local` profile is explicitly requested.

Stop the stack while preserving named volumes:

```bash
# Run this first if the 120B quality preset is active.
./modelctl local stop
docker compose down
```

Do not add `-v` unless you intend to delete models, vector data, agent memory,
Claude state, and VS Code state.

## Select a model

Use the host-side selector before starting a new agent session:

```bash
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl use openrouter tencent/hy3:free
./modelctl use local openai/gpt-oss-20b
./modelctl use-local-coding
./modelctl use-local-coding-quality
./modelctl current
./modelctl list
```

Remote switches are immediate. A local switch can take several minutes because
LM Studio may need to download and load the model. Do not switch or stop a local
model while an agent request is using it.

Selecting a remote model leaves any running local model loaded. To move back to
cloud inference and release local resources, run both commands:

```bash
./modelctl use chutes deepseek-ai/DeepSeek-V3.2-TEE
./modelctl local stop
```

`local stop` does not rewrite the current selection. If the selected route is
still `local/model`, new requests will fail until LM Studio is started again or
a remote model is selected.

The two coding presets automatically enable the NVIDIA Compose override. A
generic local model uses the default CPU-compatible configuration unless the
override is supplied explicitly:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml \
  ./modelctl use local openai/gpt-oss-20b
```

The 120B quality preset is specific to the recorded two-GPU layout and manages
a large host swap file. Review the requirements in README before running it.

## Codex CLI

Start an interactive session in a mounted project:

```bash
docker compose exec codex bash -lc 'cd /workspaces/myProject && exec codex'
```

Run a one-shot task:

```bash
docker compose exec -T codex bash -lc \
  'cd /workspaces/myProject && codex exec --skip-git-repo-check "your task here"'
```

Inspect the configured MCP servers:

```bash
docker compose exec codex codex mcp list
```

The Codex container runs as UID 1000. Its CLI intentionally bypasses Codex's
internal approval and sandbox prompts because the unprivileged container is the
execution boundary.

## Claude Code CLI

Start an interactive session:

```bash
docker compose exec claude-code bash -lc \
  'cd /workspaces/myProject && exec claude'
```

Run a one-shot task:

```bash
docker compose exec -T claude-code bash -lc \
  'cd /workspaces/myProject && claude -p "your task here"'
```

Claude uses the same `modelctl` selection and LiteLLM gateway as Codex. Its
home directory is persisted in the `claude_code_home` volume. The wrapper also
skips Claude's internal permission prompts inside the container.

## VS Code workspace

1. Open the repository root in VS Code.
2. Install the Dev Containers extension
   (`ms-vscode-remote.remote-containers`).
3. Run `Dev Containers: Reopen in Container` from the command palette.
4. Open a project below `/workspaces`.

The dev container attaches to the `workspace` service as user `vscode` and
opens `/workspaces`. The Codex extension and the `codex` command use the same
selection as the headless agent container.

After running `./modelctl use ...` on the host, start a new VS Code agent
session. Reload the VS Code window if an existing extension session keeps its
previous model configuration.

## Agent MCP services

The images preinstall the following MCP servers so agent startup does not need
to fetch them:

- filesystem access rooted at `/workspaces`;
- Git and HTTP fetch tools;
- persistent memory;
- sequential thinking;
- TypeScript language-server completion;
- SearXNG search; and
- Qdrant retrieval with the bundled FastEmbed model.

Codex and the VS Code workspace keep separate memory volumes. Claude memory is
stored under its persistent home volume. All three use the same Qdrant
`codebase` collection, so use separate collection names in the image
configuration if projects need isolated vector indexes.

## LiteLLM gateway

Base URL: `http://127.0.0.1:4000/v1`

Every request requires `LITELLM_MASTER_KEY` from `.env`:

```bash
curl http://127.0.0.1:4000/v1/models \
  -H 'Authorization: Bearer <LITELLM_MASTER_KEY-from-.env>' | jq .
```

Available route patterns are:

| Route | Backend |
| --- | --- |
| `chutes/<model-id>` | Chutes chat-completions endpoint |
| `chutes-responses/<model-id>` | Chutes Responses endpoint |
| `openrouter/<model-id>` | OpenRouter |
| `local/model` | Currently loaded LM Studio model |
| `text-embedding-nomic-embed-text-v1.5` | Nomic embeddings through LM Studio |

`modelctl` writes the correct route into each client configuration. Host
applications must choose the route themselves; read
`model-selection/selected.env` if they should follow the current selection.

Chat Completions example:

```bash
curl http://127.0.0.1:4000/v1/chat/completions \
  -H 'Authorization: Bearer <LITELLM_MASTER_KEY-from-.env>' \
  -H 'Content-Type: application/json' \
  -d '{"model":"chutes/deepseek-ai/DeepSeek-V3.2-TEE","messages":[{"role":"user","content":"Say hello."}]}'
```

Responses example:

```bash
curl http://127.0.0.1:4000/v1/responses \
  -H 'Authorization: Bearer <LITELLM_MASTER_KEY-from-.env>' \
  -H 'Content-Type: application/json' \
  -d '{"model":"chutes-responses/deepseek-ai/DeepSeek-V3.2-TEE","input":"Say hello."}'
```

The embedding route requires the optional LM Studio service and the matching
Nomic model in its persistent model volume.

Set `LITELLM_DEBUG_MODE` in `.env` to `off`, `debug`, or `detailed`, then
recreate the gateway:

```bash
docker compose up -d --force-recreate litellm
docker compose logs -f litellm
```

Detailed logs can contain prompts, source code, tool output, and request data.

## LM Studio API

Base URL: `http://127.0.0.1:1234/v1`

The endpoint exists only while the optional local service is running:

```bash
curl http://127.0.0.1:1234/v1/models | jq .
./modelctl local list
```

The selected LLM is exposed as `local/model`. Model files persist in the
`lmstudio_models` volume after the service stops. This API is unauthenticated
but bound to host loopback.

## Qdrant

API and dashboard: `http://127.0.0.1:6333`

Open `http://127.0.0.1:6333/dashboard` in a browser for the dashboard.

The agent configuration uses the `codebase` collection and FastEmbed's
`sentence-transformers/all-MiniLM-L6-v2` embedding model.

## SearXNG

Web interface: `http://127.0.0.1:8081`

The agents access it over the internal Compose network at
`http://searxng:8080`.

## Persistent data

| Data | Storage |
| --- | --- |
| Project source | Host `./workspaces` directory |
| LM Studio models | `lmstudio_models` volume |
| Qdrant vectors | `qdrant_data` volume |
| Codex memory | `codex_cli_workspace_memory` volume |
| Workspace memory | `vscode_memory` volume |
| Claude home and memory | `claude_code_home` volume |
| VS Code server | `vscode_server` volume |
| VS Code Insiders server | `vscode_server_insiders` volume |
| VS Code settings | `vscode_data` volume |
| Current model and local startup state | Host `./model-selection` directory |
| Quality-preset swap | Host `.modelctl.swap` file |

## Execution boundary

The workspace, Codex, and Claude containers are unprivileged and do not contain
the Docker CLI or receive a Docker socket. Run container builds and Compose
commands on the host.

Agents do have outbound network access, passwordless `sudo` inside their own
containers, and write access to `/workspaces`. A containerized agent can modify
or delete mounted project files, so use normal source-control and backup
practices.

## Troubleshooting

```bash
# Service state and health
docker compose ps

# Selection state seen by the host and agent containers
./modelctl current
docker compose exec -T codex modelctl current
docker compose exec -T claude-code modelctl current

# Gateway failures
docker compose logs --tail 200 litellm

# Agent startup/configuration failures
docker compose logs --tail 200 workspace codex claude-code

# Local model startup or download failures
docker compose logs --tail 200 lmstudio

# Render and validate the effective configuration
docker compose config >/dev/null

# Include GPU exposure in configuration validation
docker compose -f docker-compose.yml -f docker-compose.nvidia.yml config >/dev/null
```

Compose requires a non-empty `LITELLM_MASTER_KEY` even for configuration and
many lifecycle commands. Ensure `.env` exists and contains the generated key.
