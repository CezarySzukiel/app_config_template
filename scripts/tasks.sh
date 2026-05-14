#!/usr/bin/env bash
set -euo pipefail

cd /workspace/backend
cmd="${1:-check}"

case "$cmd" in
  sync)
    uv sync --group dev
    ;;
  lint)
    uv run ruff check --no-fix .
    ;;
  format)
    uv run ruff format .
    ;;
  format-check)
    uv run ruff format --check .
    ;;
  typecheck)
    uv run ty check
    ;;
  test)
    uv run pytest
    ;;
  cov)
    uv run pytest --cov-report=html --cov-report=term-missing
    ;;
  fix)
    uv run ruff check . --fix
    uv run ruff format .
    ;;
  check)
    uv run ruff check --no-fix .
    uv run ruff format --check .
    uv run ty check
    uv run pytest
    ;;
  *)
    echo "Unknown command: $cmd"
    echo "Available: sync, lint, format, format-check, typecheck, test, cov, fix, check"
    exit 1
    ;;
esac
