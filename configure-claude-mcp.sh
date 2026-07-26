#!/bin/sh
set -eu

config_file="${1:?usage: configure-claude-mcp.sh /path/to/.claude.json}"

if [ -s "$config_file" ]; then
  jq empty "$config_file"
else
  printf '{}\n' > "$config_file"
fi

temporary_file="${config_file}.tmp"
jq \
  '.mcpServers = ((.mcpServers // {}) + {
    "filesystem": {
      "type": "stdio",
      "command": "mcp-server-filesystem",
      "args": ["/workspaces"],
      "env": {}
    },
    "git": {
      "type": "stdio",
      "command": "mcp-server-git",
      "args": [],
      "env": {}
    },
    "fetch": {
      "type": "stdio",
      "command": "mcp-server-fetch",
      "args": [],
      "env": {}
    },
    "memory": {
      "type": "stdio",
      "command": "mcp-server-memory",
      "args": [],
      "env": {
        "MEMORY_FILE_PATH": "/home/claude/.mcp-memory/memory.jsonl"
      }
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "mcp-server-sequential-thinking",
      "args": [],
      "env": {}
    },
    "code-completion": {
      "type": "stdio",
      "command": "typescript-lsp-mcp",
      "args": [],
      "env": {}
    },
    "searxng": {
      "type": "stdio",
      "command": "mcp-searxng",
      "args": [],
      "env": {
        "SEARXNG_URL": "http://searxng:8080"
      }
    },
    "qdrant": {
      "type": "stdio",
      "command": "mcp-server-qdrant",
      "args": [],
      "env": {
        "QDRANT_URL": "http://qdrant:6333",
        "COLLECTION_NAME": "codebase",
        "EMBEDDING_PROVIDER": "fastembed",
        "EMBEDDING_MODEL": "sentence-transformers/all-MiniLM-L6-v2",
        "FASTEMBED_CACHE_PATH": "/home/claude/.cache/fastembed"
      }
    }
  })' \
  "$config_file" > "$temporary_file"
mv "$temporary_file" "$config_file"
