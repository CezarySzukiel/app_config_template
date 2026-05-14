#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import os
import re
import socket
import subprocess
from pathlib import Path

env_file = Path(".env")

ports = [
    ("FRONTEND_PORT", 5173, "frontend", 5173),
    ("APP_DB_PORT", 5432, "db", 5432),
    ("SONAR_PORT", 9000, "sonarqube", 9000),
]


def read_env(path: Path) -> tuple[list[str], dict[str, str]]:
    if not path.exists():
        return [], {}

    lines = path.read_text(encoding="utf-8").splitlines()
    values: dict[str, str] = {}
    pattern = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$")

    for line in lines:
        match = pattern.match(line)
        if match:
            values[match.group(1)] = match.group(2).strip().strip('"').strip("'")

    return lines, values


def is_free(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind(("0.0.0.0", port))
        except OSError:
            return False
    return True


def published_port(service: str, container_port: int) -> int | None:
    try:
        result = subprocess.run(
            ["docker", "compose", "port", service, str(container_port)],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return None

    if result.returncode != 0:
        return None

    output = result.stdout.strip().splitlines()
    if not output:
        return None

    match = re.search(r":(\d+)$", output[-1])
    return int(match.group(1)) if match else None


def next_free(preferred: int, used: set[int]) -> int:
    port = preferred
    while port in used or not is_free(port):
        port += 1
    return port


def set_env(lines: list[str], key: str, value: str) -> list[str]:
    pattern = re.compile(rf"^(\s*{re.escape(key)}=).*$")
    updated = False
    result: list[str] = []

    for line in lines:
        if pattern.match(line):
            result.append(f"{key}={value}")
            updated = True
        else:
            result.append(line)

    if not updated:
        result.append(f"{key}={value}")

    return result


lines, file_values = read_env(env_file)
chosen: dict[str, int] = {}
used: set[int] = set()

for key, preferred, service, container_port in ports:
    explicit = key in os.environ
    raw_value = os.environ.get(key) or file_values.get(key) or str(preferred)

    try:
        requested = int(raw_value)
    except ValueError as error:
        raise SystemExit(f"{key} must be a TCP port number, got {raw_value!r}") from error

    current = published_port(service, container_port)
    if explicit or requested == current or (requested not in used and is_free(requested)):
        selected = requested
    else:
        selected = next_free(requested, used)

    chosen[key] = selected
    used.add(selected)

for key, value in chosen.items():
    lines = set_env(lines, key, str(value))

sonar_url = os.environ.get("SONAR_URL") or file_values.get("SONAR_URL")
if not sonar_url or re.fullmatch(r"http://localhost:\d+", sonar_url):
    lines = set_env(lines, "SONAR_URL", f"http://localhost:{chosen['SONAR_PORT']}")

env_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

print("Using host ports:")
print(f"  Frontend: http://localhost:{chosen['FRONTEND_PORT']}")
print(f"  DB: localhost:{chosen['APP_DB_PORT']}")
print(f"  SonarQube: http://localhost:{chosen['SONAR_PORT']}")
PY
