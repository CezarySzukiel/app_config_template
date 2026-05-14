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
