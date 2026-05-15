#!/usr/bin/env bash
set -euo pipefail

optional=0
token="${SONATYPE_GUIDE_MCP_TOKEN:-}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$root_dir"

load_env_file() {
  env_file="$1"
  if [ -f "$env_file" ]; then
    set -a
    . "./$env_file"
    set +a
  fi
}

load_env_file ".env"
load_env_file ".env.sonar"

if [ -n "${SONATYPE_GUIDE_MCP_TOKEN:-}" ]; then
  token="$SONATYPE_GUIDE_MCP_TOKEN"
fi

if [ -n "${SONAR_MCP_PORT:-}" ] && [ -z "${SONAR_MCP_URL:-}" ]; then
  SONAR_MCP_URL="http://127.0.0.1:${SONAR_MCP_PORT}/mcp"
fi

if [ -n "${ZAP_MCP_PORT:-}" ] && [ -z "${ZAP_MCP_URL:-}" ]; then
  ZAP_MCP_URL="http://127.0.0.1:${ZAP_MCP_PORT}"
fi

if [ -z "${SONAR_MCP_READ_ONLY:-}" ]; then
  SONAR_MCP_READ_ONLY=true
fi

if [ -z "${SONAR_MCP_URL:-}" ]; then
  SONAR_MCP_URL="http://127.0.0.1:8090/mcp"
fi

if [ -z "${ZAP_MCP_URL:-}" ]; then
  ZAP_MCP_URL="http://127.0.0.1:8282"
fi

if [ -z "${ZAP_MCP_SECURITY_KEY:-}" ]; then
  ZAP_MCP_SECURITY_KEY="local-zap-mcp-change-me"
fi

if [ -z "${SONAR_MCP_USER_TOKEN:-}" ]; then
  SONAR_MCP_USER_TOKEN=""
fi

if [ -z "${SONAR_URL:-}" ]; then
  SONAR_URL="http://localhost:9000"
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
      echo "Writes .bob/mcp.json and .vscode/mcp.json with local MCP endpoints."
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
mkdir -p .vscode

tmp_file="$(mktemp .bob/mcp.json.XXXXXX)"
chmod 600 "$tmp_file"

SONATYPE_GUIDE_MCP_TOKEN="$token" \
ZAP_MCP_URL="$ZAP_MCP_URL" \
ZAP_MCP_SECURITY_KEY="$ZAP_MCP_SECURITY_KEY" \
SONAR_MCP_URL="$SONAR_MCP_URL" \
SONAR_MCP_USER_TOKEN="$SONAR_MCP_USER_TOKEN" \
SONAR_MCP_READ_ONLY="$SONAR_MCP_READ_ONLY" \
python3 - <<'PY' > "$tmp_file"
from __future__ import annotations

import json
import os

sonatype_token = os.environ.get("SONATYPE_GUIDE_MCP_TOKEN", "")
sonar_token = os.environ.get("SONAR_MCP_USER_TOKEN", "")
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

if sonar_token:
    config["mcpServers"]["sonarqube"] = {
        "type": "streamable-http",
        "url": os.environ["SONAR_MCP_URL"],
        "headers": {
            "Authorization": f"Bearer {sonar_token}",
            "SONARQUBE_READ_ONLY": os.environ.get("SONAR_MCP_READ_ONLY", "true"),
        },
        "alwaysAllow": [],
        "disabled": False,
    }

if sonatype_token:
    config["mcpServers"]["sonatypeGuide"] = {
        "type": "streamable-http",
        "url": "https://mcp.guide.sonatype.com/mcp",
        "headers": {
            "Authorization": f"Bearer {sonatype_token}",
        },
        "alwaysAllow": [],
        "disabled": False,
    }

print(json.dumps(config, indent=2))
PY

mv "$tmp_file" .bob/mcp.json
chmod 600 .bob/mcp.json

tmp_file="$(mktemp .vscode/mcp.json.XXXXXX)"
chmod 600 "$tmp_file"

SONATYPE_GUIDE_MCP_TOKEN="$token" \
SONAR_MCP_URL="$SONAR_MCP_URL" \
SONAR_MCP_USER_TOKEN="$SONAR_MCP_USER_TOKEN" \
SONAR_MCP_READ_ONLY="$SONAR_MCP_READ_ONLY" \
python3 - <<'PY' > "$tmp_file"
from __future__ import annotations

import json
import os

sonatype_token = os.environ.get("SONATYPE_GUIDE_MCP_TOKEN", "")
sonar_token = os.environ.get("SONAR_MCP_USER_TOKEN", "")

config = {
    "inputs": [],
    "servers": {},
}

if sonar_token:
    config["servers"]["sonarqube"] = {
        "type": "http",
        "url": os.environ["SONAR_MCP_URL"],
        "headers": {
            "Authorization": f"Bearer {sonar_token}",
            "SONARQUBE_READ_ONLY": os.environ.get("SONAR_MCP_READ_ONLY", "true"),
        },
    }

if sonatype_token:
    sonatype_authorization = f"Bearer {sonatype_token}"
else:
    config["inputs"].append(
        {
            "type": "promptString",
            "id": "sonatype-guide-mcp-token",
            "description": "Sonatype Guide MCP API key",
            "password": True,
        }
    )
    sonatype_authorization = "Bearer ${input:sonatype-guide-mcp-token}"

config["servers"]["sonatypeGuide"] = {
    "type": "http",
    "url": "https://mcp.guide.sonatype.com/mcp",
    "headers": {
        "Authorization": sonatype_authorization,
    },
}

if not config["inputs"]:
    del config["inputs"]

print(json.dumps(config, indent=2))
PY

mv "$tmp_file" .vscode/mcp.json
chmod 600 .vscode/mcp.json

if [ -z "$SONAR_MCP_USER_TOKEN" ]; then
  echo "Configured IBM Bob and VS Code for OWASP ZAP/Sonatype MCP. SonarQube MCP skipped because .env.sonar has no SONAR_MCP_USER_TOKEN yet."
elif [ -z "$token" ]; then
  echo "Configured IBM Bob and VS Code to use official OWASP ZAP and SonarQube MCP servers."
  echo "Skipped Sonatype Guide MCP because no token was provided."
else
  echo "Configured IBM Bob and VS Code to use official OWASP ZAP, SonarQube, and Sonatype Guide MCP servers."
fi
