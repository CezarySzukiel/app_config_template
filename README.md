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

## AI MCP

This template includes project MCP configuration for IBM Bob and workspace MCP
configuration for VS Code Copilot.

For IBM Bob, run:

```bash
./scripts/configure-bob-mcp.sh
```

or non-interactively:

```bash
SONATYPE_GUIDE_MCP_TOKEN=sonatype_pat_xxx ./scripts/configure-bob-mcp.sh
```

The script writes `.bob/mcp.json`, which is ignored by Git because it contains
the API key. The tracked `.bob/mcp.example.json` file documents the expected
configuration shape. `./init.sh` also runs this configuration step and prompts
for the key when started from an interactive terminal.

This template includes workspace MCP configuration for Sonatype Guide in
`.vscode/mcp.json`. When VS Code starts the MCP server for the first time, it
prompts for the Sonatype Guide MCP API key and stores it securely in the local
VS Code profile. The key is not written to the repository.

Open Copilot Chat in Agent mode and enable the `sonatypeGuide` tools when
working with dependencies, package versions, or supply-chain security.
