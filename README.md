# __PROJECT_NAME__

<!-- TEMPLATE-ONLY-BEGIN -->
## Initialize From Template

```bash
git clone <template-url> project_name
cd project_name
./init.sh
```

The directory name is used to initialize project names. For example, cloning into
`my-project` creates the Python package `my_project`, backend project
`my-project-backend`, and frontend project `my-project-frontend`.

`./init.sh` removes template-only files, creates a new Git repository, makes the
initial commit, and starts Docker Compose.
<!-- TEMPLATE-ONLY-END -->

## Start

```bash
./scripts/compose-up.sh
```

After cloning an already initialized project, start services and configure local
SonarQube secrets:

```bash
./scripts/compose-up.sh -d
./scripts/sonar-bootstrap.sh
```

## Services

- Frontend: http://localhost:${FRONTEND_PORT:-5173}
- DB: localhost:${APP_DB_PORT:-5432}
- OWASP ZAP API: http://127.0.0.1:${ZAP_PORT:-8080}
- OWASP ZAP MCP: http://127.0.0.1:${ZAP_MCP_PORT:-8282}
- SonarQube: http://localhost:${SONAR_PORT:-9000}

`./scripts/compose-up.sh` writes local host ports to `.env`. If a default port is
busy, the next free port is used, so multiple clones can run side by side. After
`.env` exists, plain `docker compose up` uses the same ports.

## Commands

```bash
docker compose exec backend bash /workspace/scripts/tasks.sh check
docker compose exec backend bash /workspace/scripts/tasks.sh test
docker compose exec backend bash /workspace/scripts/tasks.sh fix
```

Run a local OWASP ZAP baseline scan against the frontend from inside the Docker
Compose network:

```bash
./scripts/zap-scan.sh
```

Reports are written to `zap/reports/`. The default target is
`http://frontend:5173`; pass another target as the first argument or set
`ZAP_TARGET`.

## AI MCP

This template includes project MCP configuration for IBM Bob and workspace MCP
configuration for VS Code Copilot.

For IBM Bob, run:

```bash
./scripts/configure-bob-mcp.sh
```

The script writes `.bob/mcp.json`, which is ignored by Git because it contains
local secrets. It always adds the `owaspZap` server, pointing Bob directly at
the official OWASP ZAP MCP Integration add-on running inside the ZAP daemon.
`./init.sh` runs this after `.env` is generated, so a freshly initialized
project is ready for Bob to use official ZAP MCP tools immediately.

To also configure Sonatype Guide, run non-interactively:

```bash
SONATYPE_GUIDE_MCP_TOKEN=sonatype_pat_xxx ./scripts/configure-bob-mcp.sh
```

The tracked `.bob/mcp.example.json` file documents the expected IBM Bob
configuration shape. Open Bob, enable MCP servers, and enable the `owaspZap`
tools. The target URL visible to the ZAP daemon is written to `.env` as
`ZAP_MCP_TARGET`. Prefer the official `zap_baseline_scan` prompt first; use
`zap_full_scan` and active-scan tools only for systems you own or have
permission to test.

The ZAP daemon uses Docker host networking so the official ZAP MCP server can
stay on localhost, as recommended by the ZAP documentation, while still being
reachable by IBM Bob on the host.

This template includes workspace MCP configuration for Sonatype Guide in
`.vscode/mcp.json`. When VS Code starts the MCP server for the first time, it
prompts for the Sonatype Guide MCP API key and stores it securely in the local
VS Code profile. The key is not written to the repository.

Open Copilot Chat in Agent mode and enable the `sonatypeGuide` tools when
working with dependencies, package versions, or supply-chain security.
