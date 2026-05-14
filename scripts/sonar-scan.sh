#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".env.sonar" ]; then
  echo "Missing .env.sonar. Run scripts/sonar-bootstrap.sh first."
  exit 1
fi

docker compose build backend

docker compose run --rm backend \
  bash -lc "uv sync --group dev && bash /workspace/scripts/tasks.sh cov-xml"

set -a
. ./.env.sonar
set +a

run_sonar_scan() {
  project_dir="$1"
  project_token="$2"

  SONAR_TOKEN="$project_token" \
    docker compose --env-file .env.sonar run --rm \
      --workdir "/usr/src/${project_dir}" \
      -e SONAR_HOST_URL \
      -e SONAR_TOKEN \
      sonar-scanner
}

run_sonar_scan backend "$SONAR_BACKEND_TOKEN"
run_sonar_scan frontend "$SONAR_FRONTEND_TOKEN"
