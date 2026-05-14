from __future__ import annotations

import json
import re
import sys
import unicodedata
from typing import Any
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_FILE = Path(__file__).with_name("template-config.json")


def normalize_ascii(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return normalized.encode("ascii", "ignore").decode("ascii")


def normalize_project_name(value: str) -> str:
    value = normalize_ascii(value).strip().lower()
    value = re.sub(r"[^a-z0-9_-]+", "-", value)
    value = re.sub(r"[-_]+", "-", value)
    value = value.strip("-")

    if not value:
        raise ValueError("Project name is empty after normalization.")

    if not re.match(r"^[a-z0-9][a-z0-9_-]*$", value):
        raise ValueError(f"Invalid project name: {value!r}")

    return value


def normalize_package_name(project_name: str) -> str:
    value = project_name.replace("-", "_")
    value = re.sub(r"[^a-zA-Z0-9_]", "_", value)

    if not re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*$", value):
        value = f"project_{value}"

    return value


def load_config() -> dict[str, Any]:
    return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))


def should_process_file(path: Path, config: dict[str, Any]) -> bool:
    relative = path.relative_to(ROOT)

    if any(part in config["skip_dirs"] for part in relative.parts):
        return False

    if path.name in config["skip_files"]:
        return False

    return path.suffix in config["text_suffixes"] or path.name in config["text_file_names"]


def remove_template_blocks(text: str, config: dict[str, Any], path: Path) -> str:
    start = config["template_block_start"]
    end = config["template_block_end"]

    while start in text:
        start_index = text.index(start)
        try:
            end_index = text.index(end, start_index) + len(end)
        except ValueError as error:
            raise ValueError(f"Missing template block end marker in {path}") from error

        prefix = text[:start_index].rstrip()
        suffix = text[end_index:].lstrip("\n")
        text = f"{prefix}\n\n{suffix}" if prefix and suffix else f"{prefix}{suffix}"

    return text


def replace_placeholders(values: dict[str, str], config: dict[str, Any]) -> None:
    for path in ROOT.rglob("*"):
        if not path.is_file() or not should_process_file(path, config):
            continue

        text = path.read_text(encoding="utf-8")
        updated = remove_template_blocks(text, config, path)
        for placeholder, value in values.items():
            updated = updated.replace(placeholder, value)

        if updated != text:
            path.write_text(updated, encoding="utf-8")


def rename_placeholder_paths(values: dict[str, str], config: dict[str, Any]) -> None:
    paths = sorted(ROOT.rglob("*"), key=lambda item: len(item.parts), reverse=True)

    for path in paths:
        relative = path.relative_to(ROOT)
        if any(part in config["skip_dirs"] for part in relative.parts):
            continue

        new_name = path.name
        for placeholder, value in values.items():
            new_name = new_name.replace(placeholder, value)

        if new_name == path.name:
            continue

        target = path.with_name(new_name)
        if target.exists():
            raise FileExistsError(f"Target path already exists: {target}")

        path.rename(target)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 .template/bootstrap.py <project-name>")

    project_name = normalize_project_name(sys.argv[1])
    package_name = normalize_package_name(project_name)
    config = load_config()

    values = {
        "__PROJECT_NAME__": project_name,
        "__BACKEND_NAME__": f"{project_name}-backend",
        "__FRONTEND_NAME__": f"{project_name}-frontend",
        "__PACKAGE_NAME__": package_name,
    }

    replace_placeholders(values, config)
    rename_placeholder_paths(values, config)

    print(f"Project: {project_name}")
    print(f"Package: {package_name}")


if __name__ == "__main__":
    main()
