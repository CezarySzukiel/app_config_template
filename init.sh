#!/usr/bin/env sh
set -eu

if [ ! -f ".template-source" ]; then
  echo "This project looks already initialized."
  exit 1
fi

PROJECT_NAME="$(
  python3 -c 'import sys; sys.path.insert(0, ".template"); from bootstrap import normalize_project_name; print(normalize_project_name(sys.argv[1]))' "$(basename "$PWD")"
)"

python3 .template/bootstrap.py "$PROJECT_NAME"

chmod +x scripts/*.sh 2>/dev/null || true

bash scripts/configure-ports.sh
set -a
. ./.env
set +a

bash scripts/configure-bob-mcp.sh --optional

rm -rf .git
git init -b main 2>/dev/null || git init

rm -rf .template
rm -f .template-source
rm -f init.sh

git add .
git commit -m "Initial project setup" || true

echo "Project initialized: $PROJECT_NAME"
echo "Starting Docker Compose..."

docker compose up -d --build

echo "Configuring SonarQube..."

bash scripts/sonar-bootstrap.sh "$PROJECT_NAME" "$PROJECT_NAME"

if [ "${RUN_SONAR_SCAN:-1}" != "0" ]; then
  bash scripts/sonar-scan.sh
fi

echo "Project initialized: $PROJECT_NAME"
echo "SonarQube: ${SONAR_URL}"
echo "To run Sonar scan later: ./scripts/sonar-scan.sh"
echo "OWASP ZAP: ${ZAP_BASE_URL}"
echo "OWASP ZAP MCP: ${ZAP_MCP_URL}"
echo "To run ZAP baseline scan later: ./scripts/zap-scan.sh"

docker compose logs -f backend frontend zap sonarqube
