#!/usr/bin/env bash
set -euo pipefail

PROJECT_KEY_PREFIX="${1:?Usage: scripts/sonar-bootstrap.sh <project-key-prefix> [project-name]}"
PROJECT_NAME="${2:-$PROJECT_KEY_PREFIX}"
BACKEND_PROJECT_KEY="${PROJECT_KEY_PREFIX}-backend"
FRONTEND_PROJECT_KEY="${PROJECT_KEY_PREFIX}-frontend"

REQUESTED_SONAR_URL="${SONAR_URL:-}"
REQUESTED_SONAR_PORT="${SONAR_PORT:-}"
REQUESTED_SONAR_HOST_URL="${SONAR_HOST_URL:-}"
REQUESTED_SONAR_ADMIN_LOGIN="${SONAR_ADMIN_LOGIN:-}"
REQUESTED_SONAR_ADMIN_PASSWORD="${SONAR_ADMIN_PASSWORD:-}"

if [ -f ".env.sonar" ]; then
  set -a
  . ./.env.sonar
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
    openssl rand -hex 24
  else
    python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
  fi
}

SONAR_ADMIN_PASSWORD="${REQUESTED_SONAR_ADMIN_PASSWORD:-${SONAR_ADMIN_PASSWORD:-$(generate_secret)}}"

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"
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

  sleep 2
done

if [ "$ready" != "1" ]; then
  echo "SonarQube did not become ready at ${SONAR_URL}." >&2
  exit 1
fi

echo "Trying first-time admin password change..."

curl -fsS \
  -u "admin:admin" \
  -X POST "${SONAR_URL}/api/users/change_password" \
  --data-urlencode "login=${SONAR_ADMIN_LOGIN}" \
  --data-urlencode "previousPassword=admin" \
  --data-urlencode "password=${SONAR_ADMIN_PASSWORD}" \
  >/dev/null || true

create_project() {
  project_key="$1"
  project_name="$2"
  project_query="$(urlencode "$project_key")"

  project_total="$(
    curl -fsS \
      -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
      "${SONAR_URL}/api/projects/search?projects=${project_query}" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("paging", {}).get("total", 0))'
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

  curl -fsS \
    -u "${SONAR_ADMIN_LOGIN}:${SONAR_ADMIN_PASSWORD}" \
    -X POST "${SONAR_URL}/api/user_tokens/generate" \
    --data-urlencode "name=${token_name}" \
    --data-urlencode "type=PROJECT_ANALYSIS_TOKEN" \
    --data-urlencode "projectKey=${project_key}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'
}

echo "Creating SonarQube projects if missing..."

create_project "$BACKEND_PROJECT_KEY" "${PROJECT_NAME} Backend"
create_project "$FRONTEND_PROJECT_KEY" "${PROJECT_NAME} Frontend"

echo "Generating project analysis tokens..."

SONAR_BACKEND_TOKEN="$(generate_project_token "$BACKEND_PROJECT_KEY")"
SONAR_FRONTEND_TOKEN="$(generate_project_token "$FRONTEND_PROJECT_KEY")"

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
EOF
chmod 600 .env.sonar

echo "SonarQube configured."
echo "UI: ${SONAR_URL}"
echo "Backend project key: ${BACKEND_PROJECT_KEY}"
echo "Frontend project key: ${FRONTEND_PROJECT_KEY}"
echo "Secrets saved to .env.sonar"
