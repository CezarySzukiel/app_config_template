FROM ghcr.io/astral-sh/uv:python3.14-bookworm

WORKDIR /workspace/backend

ENV UV_PROJECT_ENVIRONMENT=/workspace/backend/.venv
ENV UV_LINK_MODE=copy
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
