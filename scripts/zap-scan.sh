#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if [ -f ".env" ]; then
  set -a
  . ./.env
  set +a
fi

target="${1:-${ZAP_TARGET:-http://frontend:5173}}"
timeout_mins="${ZAP_TIMEOUT_MINS:-5}"
reports_dir="zap/reports"
fail_on_warn="${ZAP_FAIL_ON_WARN:-0}"

mkdir -p "$reports_dir"

args=(
  zap-baseline.py
  -t "$target"
  -c /zap/wrk/baseline.conf
  -r reports/zap-baseline.html
  -J reports/zap-baseline.json
  -w reports/zap-baseline.md
  -T "$timeout_mins"
)

if [ "$fail_on_warn" != "1" ]; then
  args+=(-I)
fi

echo "Running OWASP ZAP baseline scan against ${target}"
docker compose run --rm zap-baseline "${args[@]}"

echo "ZAP reports:"
echo "  HTML: ${reports_dir}/zap-baseline.html"
echo "  JSON: ${reports_dir}/zap-baseline.json"
echo "  Markdown: ${reports_dir}/zap-baseline.md"
