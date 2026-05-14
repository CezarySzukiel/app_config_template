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
docker compose up
```

## Services

- Frontend: http://localhost:5173
- DB: localhost:5432

## Commands

```bash
docker compose exec backend bash /workspace/scripts/tasks.sh check
docker compose exec backend bash /workspace/scripts/tasks.sh test
docker compose exec backend bash /workspace/scripts/tasks.sh fix
```
