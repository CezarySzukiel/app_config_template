#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if [ ! -f ".env" ]; then
  bash scripts/configure-ports.sh
fi

if [ ! -f ".env.sonar" ]; then
  echo "Missing .env.sonar. Run scripts/sonar-bootstrap.sh first." >&2
  exit 1
fi

set -a
. ./.env
. ./.env.sonar
set +a

bash scripts/configure-bob-mcp.sh --optional

docker compose up -d sonarqube-mcp

echo "SonarQube MCP: ${SONAR_MCP_URL:-http://127.0.0.1:${SONAR_MCP_PORT:-8090}/mcp}"
