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
./scripts/sonar-mcp-up.sh
```

## Services

- Frontend: http://localhost:${FRONTEND_PORT:-5173}
- DB: localhost:${APP_DB_PORT:-5432}
- OWASP ZAP API: http://127.0.0.1:${ZAP_PORT:-8080}
- OWASP ZAP MCP: http://127.0.0.1:${ZAP_MCP_PORT:-8282}
- SonarQube: http://localhost:${SONAR_PORT:-9000}
- SonarQube MCP: http://127.0.0.1:${SONAR_MCP_PORT:-8090}/mcp

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
local secrets. It also writes local `.vscode/mcp.json`, which is ignored by Git
for the same reason. It always adds the `owaspZap` server, pointing Bob directly
at the official OWASP ZAP MCP Integration add-on running inside the ZAP daemon.
`./init.sh` runs this after `.env` is generated, so a freshly initialized
project is ready for Bob to use official ZAP MCP tools immediately.

After `./scripts/sonar-bootstrap.sh` creates `.env.sonar`, run:

```bash
./scripts/sonar-mcp-up.sh
```

`sonar-bootstrap.sh` generates a SonarQube user token for MCP. `sonar-mcp-up.sh`
then starts the official SonarQube MCP container image (`mcp/sonarqube`) on
localhost and updates Bob and VS Code MCP configuration with the local
`sonarqube` endpoint. SonarQube project analysis tokens remain separate and are
used only by `./scripts/sonar-scan.sh`.

To also configure Sonatype Guide, run non-interactively:

```bash
SONATYPE_GUIDE_MCP_TOKEN=sonatype_pat_xxx ./scripts/configure-bob-mcp.sh
```

The tracked `.bob/mcp.example.json` and `.vscode/mcp.example.json` files
document the expected MCP configuration shape. Open Bob or VS Code, enable MCP
servers, and enable the `owaspZap` and `sonarqube` tools. The target URL visible
to the ZAP daemon is written to `.env` as
`ZAP_MCP_TARGET`. Prefer the official `zap_baseline_scan` prompt first; use
`zap_full_scan` and active-scan tools only for systems you own or have
permission to test.

The ZAP daemon uses Docker host networking so the official ZAP MCP server can
stay on localhost, as recommended by the ZAP documentation, while still being
reachable by IBM Bob on the host.

The generated `.vscode/mcp.json` includes SonarQube when `.env.sonar` exists.
When no Sonatype Guide token is provided, VS Code prompts for the Sonatype Guide
MCP API key and stores it securely in the local VS Code profile. Local tokens are
not written to the repository.

Open Copilot Chat in Agent mode and enable the `sonarqube` tools when working
with code quality or security analysis results. Enable `sonatypeGuide` tools
when working with dependencies, package versions, or supply-chain security.

The `sonar-scanner` container remains intentionally separate from SonarQube MCP:
the scanner publishes fresh analysis results to SonarQube, while MCP lets agents
query and act on those results. Keep the scanner container unless your project
will run SonarScanner from CI or a host-installed CLI instead.
