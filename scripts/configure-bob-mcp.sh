#!/usr/bin/env bash
set -euo pipefail

optional=0
token="${SONATYPE_GUIDE_MCP_TOKEN:-}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$root_dir"

if [ -f ".env" ]; then
  set -a
  . ./.env
  set +a
fi

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

if [ -z "$token" ] && [ "$optional" -ne 1 ]; then
  echo "Set SONATYPE_GUIDE_MCP_TOKEN or pass the token as the first argument." >&2
  exit 1
fi

mkdir -p .bob
tmp_file="$(mktemp .bob/mcp.json.XXXXXX)"
chmod 600 "$tmp_file"

SONATYPE_GUIDE_MCP_TOKEN="$token" \
ZAP_MCP_URL="${ZAP_MCP_URL:-http://127.0.0.1:${ZAP_MCP_PORT:-8282}}" \
ZAP_MCP_SECURITY_KEY="${ZAP_MCP_SECURITY_KEY:-local-zap-mcp-change-me}" \
python3 - <<'PY' > "$tmp_file"
from __future__ import annotations

import json
import os

token = os.environ.get("SONATYPE_GUIDE_MCP_TOKEN", "")
config = {
    "mcpServers": {
        "owaspZap": {
            "type": "streamable-http",
            "url": os.environ["ZAP_MCP_URL"],
            "headers": {
                "Authorization": os.environ["ZAP_MCP_SECURITY_KEY"],
            },
            "alwaysAllow": [],
            "disabled": False,
        }
    }
}

if token:
    config["mcpServers"]["sonatypeGuide"] = {
        "type": "streamable-http",
        "url": "https://mcp.guide.sonatype.com/mcp",
        "headers": {
            "Authorization": f"Bearer {token}",
        },
        "alwaysAllow": [],
        "disabled": False,
    }

print(json.dumps(config, indent=2))
PY

mv "$tmp_file" .bob/mcp.json
chmod 600 .bob/mcp.json

if [ -z "$token" ]; then
  echo "Configured IBM Bob to use the official OWASP ZAP MCP server in .bob/mcp.json."
  echo "Skipped Sonatype Guide MCP because no token was provided."
else
  echo "Configured IBM Bob to use official OWASP ZAP MCP and Sonatype Guide MCP in .bob/mcp.json."
fi
