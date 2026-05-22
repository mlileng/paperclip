# Paperclip Docker Setup — Design

**Date:** 2026-05-22
**Approach:** Clone source repo + use upstream docker-compose (Approach A)

## Goal

Run Paperclip in Docker locally using the official source build, with PostgreSQL as the database, so the setup translates cleanly to future cloud deployment.

## Architecture

Two containers managed by `docker/docker-compose.yml` from the cloned source:

| Container | Image | Port | Persistence |
|-----------|-------|------|-------------|
| `db` | postgres:17-alpine | internal only | named volume `pgdata` |
| `server` | built from `Dockerfile` | 3100 → 3100 | named volume `paperclip-data` |

The server waits for the `db` health check before starting.

The Dockerfile uses a multi-stage build (deps → build → production) and pre-installs `claude`, `codex`, and `opencode` CLIs in the final image.

## Setup Steps

1. Clone `https://github.com/paperclipai/paperclip.git` into `/Users/mol/code/paperclip` (replacing the existing `start.sh`)
2. Create `.env` in the project root with:
   - `BETTER_AUTH_SECRET` — generated via `openssl rand -hex 32`
   - `ANTHROPIC_API_KEY` — optional, enables Claude Code local adapter
   - `OPENAI_API_KEY` — optional, enables Codex local adapter
3. Build and start: `docker compose -f docker/docker-compose.yml up --build`
4. Access at `http://localhost:3100`

## Data Persistence

Named Docker volumes survive container restarts and `down` commands (unless `--volumes` is passed). Can be migrated to bind mounts later if a specific host path is needed.

## Future Cloud Deployment

The same compose file maps to:
- **ECS**: `docker/ecs-task-definition.json` is already in the repo
- **Any compose-compatible host**: swap named volumes for cloud storage, set `PAPERCLIP_PUBLIC_URL` to the public URL, set `PAPERCLIP_DEPLOYMENT_EXPOSURE` appropriately

## Out of Scope

- Tailscale/LAN access (can be added later via `PAPERCLIP_PUBLIC_URL` and `PAPERCLIP_ALLOWED_HOSTNAMES`)
- Untrusted PR review container (`docker-compose.untrusted-review.yml` exists upstream for this)
- Podman/Quadlet systemd deployment
