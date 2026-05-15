#!/usr/bin/env bash
set -euo pipefail

read_sonar_property() {
  file="$1"
  property="$2"

  python3 -c '
import sys
from pathlib import Path

path = Path(sys.argv[1])
property_name = sys.argv[2]

if not path.exists():
    raise SystemExit(f"Missing SonarQube properties file: {path}")

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or line.startswith("!"):
        continue
    if "=" in line:
        key, value = line.split("=", 1)
    elif ":" in line:
        key, value = line.split(":", 1)
    else:
        continue
    if key.strip() == property_name:
        print(value.strip())
        raise SystemExit(0)

raise SystemExit(f"Missing {property_name} in {path}")
' "$file" "$property"
}

read_optional_sonar_property() {
  file="$1"
  property="$2"
  fallback="$3"

  read_sonar_property "$file" "$property" 2>/dev/null || printf '%s\n' "$fallback"
}

if [ "$#" -gt 2 ]; then
  echo "Usage: scripts/sonar-bootstrap.sh [project-key-prefix] [project-name]" >&2
  exit 1
fi

if [ "$#" -ge 1 ]; then
  PROJECT_KEY_PREFIX="$1"
  PROJECT_NAME="${2:-$PROJECT_KEY_PREFIX}"
  BACKEND_PROJECT_KEY="${PROJECT_KEY_PREFIX}-backend"
  FRONTEND_PROJECT_KEY="${PROJECT_KEY_PREFIX}-frontend"
  BACKEND_PROJECT_NAME="${PROJECT_NAME} Backend"
  FRONTEND_PROJECT_NAME="${PROJECT_NAME} Frontend"
else
  BACKEND_PROJECT_KEY="$(read_sonar_property backend/sonar-project.properties sonar.projectKey)"
  FRONTEND_PROJECT_KEY="$(read_sonar_property frontend/sonar-project.properties sonar.projectKey)"
  BACKEND_PROJECT_NAME="$(read_optional_sonar_property backend/sonar-project.properties sonar.projectName "$BACKEND_PROJECT_KEY")"
  FRONTEND_PROJECT_NAME="$(read_optional_sonar_property frontend/sonar-project.properties sonar.projectName "$FRONTEND_PROJECT_KEY")"
fi

REQUESTED_SONAR_URL="${SONAR_URL:-}"
REQUESTED_SONAR_PORT="${SONAR_PORT:-}"
REQUESTED_SONAR_HOST_URL="${SONAR_HOST_URL:-}"
REQUESTED_SONAR_ADMIN_LOGIN="${SONAR_ADMIN_LOGIN:-}"
REQUESTED_SONAR_ADMIN_PASSWORD="${SONAR_ADMIN_PASSWORD:-}"

# Load persisted local secrets first, then the compose port map. This keeps
# generated tokens/passwords while making bootstrap follow the ports selected by
# scripts/configure-ports.sh after a fresh clone.
if [ -f ".env.sonar" ]; then
  set -a
  . ./.env.sonar
  set +a
fi

if [ -f ".env" ]; then
  set -a
  . ./.env
  set +a
fi

SONAR_URL="${REQUESTED_SONAR_URL:-${SONAR_URL:-http://localhost:9000}}"
SONAR_PORT="${REQUESTED_SONAR_PORT:-${SONAR_PORT:-}}"
if [ -z "$SONAR_PORT" ]; then
  SONAR_PORT="$(
    python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).port or 9000)' "$SONAR_URL"
  )"
fi
SONAR_HOST_URL="${REQUESTED_SONAR_HOST_URL:-${SONAR_HOST_URL:-http://sonarqube:9000}}"
SONAR_ADMIN_LOGIN="${REQUESTED_SONAR_ADMIN_LOGIN:-${SONAR_ADMIN_LOGIN:-admin}}"

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    printf 'A1!%sa\n' "$(openssl rand -hex 24)"
  else
    python3 - <<'PY'
import secrets
print(f"A1!{secrets.token_hex(24)}a")
PY
  fi
}

SONAR_ADMIN_PASSWORD="${REQUESTED_SONAR_ADMIN_PASSWORD:-${SONAR_ADMIN_PASSWORD:-$(generate_secret)}}"

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"
}

auth_valid() {
  login="$1"
  password="$2"

  curl -fsS \
    -u "${login}:${password}" \
    "${SONAR_URL}/api/authentication/validate" 2>/dev/null \
    | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("valid") else 1)' 2>/dev/null
}

ensure_admin_auth() {
  if auth_valid "$SONAR_ADMIN_LOGIN" "$SONAR_ADMIN_PASSWORD"; then
    echo "Using configured SonarQube admin credentials."
    return
  fi

  if ! auth_valid admin admin; then
    echo "Could not authenticate to SonarQube." >&2
    echo "The instance is already initialized, but the configured admin credentials did not work." >&2
    echo "Restore the matching .env.sonar, set SONAR_ADMIN_PASSWORD to the current admin password, or reset the SonarQube volumes." >&2
    exit 1
  fi

  if [ "$SONAR_ADMIN_LOGIN" != "admin" ]; then
    echo "A fresh SonarQube instance only has the default 'admin' user." >&2
    echo "Unset SONAR_ADMIN_LOGIN or set it to 'admin' for first-time bootstrap." >&2
    exit 1
  fi

  echo "Changing first-time SonarQube admin password..."

  curl -fsS \
    -u "admin:admin" \
    -X POST "${SONAR_URL}/api/users/change_password" \
    --data-urlencode "login=${SONAR_ADMIN_LOGIN}" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${SONAR_ADMIN_PASSWORD}" \
    >/dev/null

  if ! auth_valid "$SONAR_ADMIN_LOGIN" "$SONAR_ADMIN_PASSWORD"; then
    echo "SonarQube admin password change completed, but the new credentials were not accepted." >&2
    exit 1
  fi
}

echo "Waiting for SonarQube at ${SONAR_URL}..."

ready=0
for _ in $(seq 1 120); do
  status="$(
    curl -fsS "${SONAR_URL}/api/system/status" 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null \
      || true
  )"

  if [ "$status" = "UP" ] || [ "$status" = "GREEN" ]; then
    ready=1
    break
  fi

  sonarqube_container="$(docker compose ps -q sonarqube 2>/dev/null || true)"
  if [ -n "$sonarqube_container" ]; then
    sonarqube_running="$(docker inspect -f '{{.State.Running}}' "$sonarqube_container" 2>/dev/null || true)"
    if [ "$sonarqube_running" = "false" ]; then
      echo "SonarQube container stopped before becoming ready." >&2
      echo "Check logs with: docker compose logs sonarqube sonar-db" >&2
      exit 1
    fi
  fi

  sleep 2
done

if [ "$ready" != "1" ]; then
  echo "SonarQube did not become ready at ${SONAR_URL}." >&2
  exit 1
fi

ensure_admin_auth

create_project() {
  project_key="$1"
  project_name="$2"
  project_query="$(urlencode "$project_key")"
  project_response="$(
    curl -fsS \
      -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
      "${SONAR_URL}/api/projects/search?projects=${project_query}"
  )" || {
    echo "Failed to search for SonarQube project '${project_key}'." >&2
    exit 1
  }

  project_total="$(
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("paging", {}).get("total", 0))' <<<"$project_response"
  )"

  if [ "$project_total" = "0" ]; then
    curl -fsS \
      -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
      -X POST "${SONAR_URL}/api/projects/create" \
      --data-urlencode "project=${project_key}" \
      --data-urlencode "name=${project_name}" \
      >/dev/null
  fi
}

generate_project_token() {
  project_key="$1"
  token_name="${project_key}-analysis-$(date +%Y%m%d%H%M%S)"
  token_response="$(
    curl -fsS \
      -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
      -X POST "${SONAR_URL}/api/user_tokens/generate" \
      --data-urlencode "name=${token_name}" \
      --data-urlencode "type=PROJECT_ANALYSIS_TOKEN" \
      --data-urlencode "projectKey=${project_key}"
  )" || {
    echo "Failed to generate SonarQube analysis token for '${project_key}'." >&2
    exit 1
  }

  python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])' <<<"$token_response"
}

auth_token_valid() {
  token="$1"

  [ -n "$token" ] || return 1

  curl -fsS \
    -u "${token}:" \
    "${SONAR_URL}/api/authentication/validate" 2>/dev/null \
    | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("valid") else 1)' 2>/dev/null
}

generate_user_token() {
  token_name="local-mcp-user-$(date +%Y%m%d%H%M%S)"
  token_response="$(
    curl -fsS \
      -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
      -X POST "${SONAR_URL}/api/user_tokens/generate" \
      --data-urlencode "name=${token_name}" \
      --data-urlencode "type=USER_TOKEN"
  )" || {
    echo "Failed to generate SonarQube user token for MCP." >&2
    exit 1
  }

  python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])' <<<"$token_response"
}

echo "Creating SonarQube projects if missing..."

create_project "$BACKEND_PROJECT_KEY" "$BACKEND_PROJECT_NAME"
create_project "$FRONTEND_PROJECT_KEY" "$FRONTEND_PROJECT_NAME"

echo "Generating project analysis tokens..."

SONAR_BACKEND_TOKEN="$(generate_project_token "$BACKEND_PROJECT_KEY")"
SONAR_FRONTEND_TOKEN="$(generate_project_token "$FRONTEND_PROJECT_KEY")"

if auth_token_valid "${SONAR_MCP_USER_TOKEN:-}"; then
  echo "Reusing existing SonarQube MCP user token."
else
  echo "Generating SonarQube MCP user token..."
  SONAR_MCP_USER_TOKEN="$(generate_user_token)"
fi

umask 077

cat > .env.sonar <<EOF
SONAR_URL=${SONAR_URL}
SONAR_PORT=${SONAR_PORT}
SONAR_HOST_URL=${SONAR_HOST_URL}
SONAR_BACKEND_PROJECT_KEY=${BACKEND_PROJECT_KEY}
SONAR_FRONTEND_PROJECT_KEY=${FRONTEND_PROJECT_KEY}
SONAR_ADMIN_LOGIN=${SONAR_ADMIN_LOGIN}
SONAR_ADMIN_PASSWORD=${SONAR_ADMIN_PASSWORD}
SONAR_BACKEND_TOKEN=${SONAR_BACKEND_TOKEN}
SONAR_FRONTEND_TOKEN=${SONAR_FRONTEND_TOKEN}
SONAR_MCP_USER_TOKEN=${SONAR_MCP_USER_TOKEN}
SONAR_MCP_READ_ONLY=${SONAR_MCP_READ_ONLY:-true}
EOF
chmod 600 .env.sonar

echo "SonarQube configured."
echo "UI: ${SONAR_URL}"
echo "Backend project key: ${BACKEND_PROJECT_KEY}"
echo "Frontend project key: ${FRONTEND_PROJECT_KEY}"
echo "Secrets saved to .env.sonar"
