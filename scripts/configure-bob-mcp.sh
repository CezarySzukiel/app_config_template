#!/usr/bin/env bash
set -euo pipefail

optional=0
token="${SONATYPE_GUIDE_MCP_TOKEN:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --optional)
      optional=1
      shift
      ;;
    -h|--help)
      echo "Usage: SONATYPE_GUIDE_MCP_TOKEN=<token> $0 [--optional]"
      echo "       $0 [--optional] <token>"
      exit 0
      ;;
    *)
      if [ -n "$token" ]; then
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      token="$1"
      shift
      ;;
  esac
done

if [ -z "$token" ] && [ -t 0 ]; then
  printf "Sonatype Guide MCP API key for IBM Bob (leave empty to skip): "
  IFS= read -r -s token
  printf "\n"
fi

if [ -z "$token" ]; then
  if [ "$optional" -eq 1 ]; then
    echo "Skipping IBM Bob Sonatype MCP configuration."
    exit 0
  fi

  echo "Set SONATYPE_GUIDE_MCP_TOKEN or pass the token as the first argument." >&2
  exit 1
fi

mkdir -p .bob
tmp_file="$(mktemp .bob/mcp.json.XXXXXX)"
chmod 600 "$tmp_file"

SONATYPE_GUIDE_MCP_TOKEN="$token" python3 - <<'PY' > "$tmp_file"
from __future__ import annotations

import json
import os

token = os.environ["SONATYPE_GUIDE_MCP_TOKEN"]
config = {
    "mcpServers": {
        "sonatypeGuide": {
            "type": "streamable-http",
            "url": "https://mcp.guide.sonatype.com/mcp",
            "headers": {
                "Authorization": f"Bearer {token}",
            },
            "alwaysAllow": [],
            "disabled": False,
        }
    }
}

print(json.dumps(config, indent=2))
PY

mv "$tmp_file" .bob/mcp.json
chmod 600 .bob/mcp.json

echo "Configured IBM Bob MCP in .bob/mcp.json."
