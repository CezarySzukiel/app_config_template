#!/usr/bin/env sh
set -eu

if [ ! -f ".template-source" ]; then
  echo "This project looks already initialized."
  exit 1
fi

PROJECT_NAME="$(basename "$PWD")"

python3 .template/bootstrap.py "$PROJECT_NAME"

rm -rf .git
git init -b main 2>/dev/null || git init

rm -rf .template
rm -f .template-source
rm -f init.sh

git add .
git commit -m "Initial project setup" || true

echo "Project initialized: $PROJECT_NAME"
echo "Starting Docker Compose..."

docker compose up
