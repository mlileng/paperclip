# Paperclip Docker Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run Paperclip locally in Docker using a source build, with PostgreSQL as the database.

**Architecture:** Clone the upstream `paperclipai/paperclip` repo into `/Users/mol/code/paperclip`, preserving the design docs already created there. Use the upstream `docker/docker-compose.yml` which wires a `db` (PostgreSQL 17) and `server` (Paperclip app) container. Data persists via named Docker volumes.

**Tech Stack:** Docker, docker compose, PostgreSQL 17, Node.js/TypeScript (built inside image), pnpm

---

### Task 1: Clone the source repo

**Files:**
- Replaces: `/Users/mol/code/paperclip/start.sh` (no longer needed)
- Preserves: `/Users/mol/code/paperclip/docs/` (move back after clone)

- [ ] **Step 1: Back up docs we've already written**

```bash
cp -r /Users/mol/code/paperclip/docs /tmp/paperclip-docs-backup
```

Expected: no output, `/tmp/paperclip-docs-backup/` exists.

- [ ] **Step 2: Clone the repo to a temp location**

```bash
git clone https://github.com/paperclipai/paperclip.git /tmp/paperclip-src
```

Expected: output ending with `Resolving deltas: done.`

- [ ] **Step 3: Move repo contents into the working directory**

The target directory has `start.sh` and `docs/` — we overwrite with the cloned source (including `.git`) and restore our docs afterwards.

```bash
rsync -a /tmp/paperclip-src/ /Users/mol/code/paperclip/
cp -r /tmp/paperclip-docs-backup/. /Users/mol/code/paperclip/docs/
```

Expected: no output. The working directory is now a proper git repo pointing at `origin`.

Future updates: `git -C /Users/mol/code/paperclip pull`

- [ ] **Step 4: Verify key files and git remote are present**

```bash
ls /Users/mol/code/paperclip/Dockerfile /Users/mol/code/paperclip/docker/docker-compose.yml /Users/mol/code/paperclip/package.json
git -C /Users/mol/code/paperclip remote -v
```

Expected: all three paths printed (no "No such file" errors), and `origin` pointing at `https://github.com/paperclipai/paperclip.git`.

---

### Task 2: Create the .env file

**Files:**
- Create: `/Users/mol/code/paperclip/.env`

The upstream `docker/docker-compose.yml` requires `BETTER_AUTH_SECRET`. API keys are optional but needed for local agent runs.

- [ ] **Step 1: Generate BETTER_AUTH_SECRET and write .env**

```bash
cat > /Users/mol/code/paperclip/.env <<EOF
BETTER_AUTH_SECRET=$(openssl rand -hex 32)
# ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=sk-...
EOF
```

Expected: no output.

- [ ] **Step 2: Verify .env was written with a non-empty secret**

```bash
grep BETTER_AUTH_SECRET /Users/mol/code/paperclip/.env
```

Expected: `BETTER_AUTH_SECRET=` followed by 64 hex characters.

- [ ] **Step 3: Add API keys if you have them**

Edit `/Users/mol/code/paperclip/.env` and uncomment/fill in `ANTHROPIC_API_KEY` and/or `OPENAI_API_KEY`. These are optional — the app runs without them, but local Claude Code or Codex adapters won't authenticate.

- [ ] **Step 4: Ensure .env is git-ignored**

```bash
grep -q '^\.env$' /Users/mol/code/paperclip/.gitignore && echo "already ignored" || echo ".env" >> /Users/mol/code/paperclip/.gitignore
```

Expected: `already ignored` (the upstream .gitignore already includes it). If not, `.env` is appended.

---

### Task 3: Build the Docker image

**Files:**
- Read: `/Users/mol/code/paperclip/Dockerfile`
- Read: `/Users/mol/code/paperclip/docker/docker-compose.yml`

The build passes your host UID/GID so bind-mounted volume files are owned by your user, not root.

- [ ] **Step 1: Build both services**

Run from the project root (not `docker/`):

```bash
cd /Users/mol/code/paperclip && \
  USER_UID=$(id -u) USER_GID=$(id -g) \
  docker compose -f docker/docker-compose.yml build
```

This takes 5–15 minutes on first run (installs pnpm deps, compiles TypeScript, installs Claude/Codex/OpenCode CLIs).

Expected: output ending with lines like:
```
 => exporting to image
 => => writing image sha256:...
 => => naming to docker.io/library/paperclip-server
```

No `ERROR` lines.

- [ ] **Step 2: Verify the image was created**

```bash
docker images | grep paperclip
```

Expected: at least one row with `paperclip` in the name and a size in the hundreds of MB range.

---

### Task 4: Start the services

**Files:**
- Read: `/Users/mol/code/paperclip/docker/docker-compose.yml`

- [ ] **Step 1: Start in detached mode**

```bash
cd /Users/mol/code/paperclip && \
  USER_UID=$(id -u) USER_GID=$(id -g) \
  docker compose -f docker/docker-compose.yml up -d
```

Expected output:
```
[+] Running 3/3
 ✔ Network paperclip_default   Created
 ✔ Container paperclip-db-1    Started
 ✔ Container paperclip-server-1 Started
```

- [ ] **Step 2: Wait for PostgreSQL to be healthy**

```bash
until docker compose -f /Users/mol/code/paperclip/docker/docker-compose.yml ps | grep "db" | grep "healthy"; do
  echo "Waiting for db..."; sleep 3
done
echo "DB is healthy"
```

Expected: `DB is healthy` within ~30 seconds.

- [ ] **Step 3: Check both containers are running**

```bash
docker compose -f /Users/mol/code/paperclip/docker/docker-compose.yml ps
```

Expected: both `db` and `server` show `running` (or `Up`) status with no `Exit` or `Restarting`.

---

### Task 5: Verify the app is accessible

- [ ] **Step 1: Tail the server logs briefly**

```bash
docker compose -f /Users/mol/code/paperclip/docker/docker-compose.yml logs --tail=40 server
```

Expected: log lines including something like `Listening on http://0.0.0.0:3100` and no `FATAL` errors.

- [ ] **Step 2: Hit the health endpoint**

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/health 2>/dev/null || \
  curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/api/health 2>/dev/null || \
  curl -s -o /dev/null -w "%{http_code}" http://localhost:3100
```

Expected: `200` (or `301`/`302` redirect to login page). Any 2xx or 3xx means the server is up.

- [ ] **Step 3: Open in browser**

Navigate to `http://localhost:3100`. You should see the Paperclip login/onboarding page.

---

### Task 6: Convenience scripts and commit

- [ ] **Step 1: Replace start.sh with a compose-aware start script**

```bash
cat > /Users/mol/code/paperclip/start.sh <<'EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"
USER_UID=$(id -u) USER_GID=$(id -g) \
  docker compose -f docker/docker-compose.yml up -d
echo "Paperclip running at http://localhost:3100"
echo "Logs: docker compose -f docker/docker-compose.yml logs -f"
echo "Stop: docker compose -f docker/docker-compose.yml down"
EOF
chmod +x /Users/mol/code/paperclip/start.sh
```

- [ ] **Step 2: Commit local additions**

```bash
cd /Users/mol/code/paperclip
git add docs/ start.sh
git commit -m "chore: add local docker setup scripts and design docs"
```

---

## Reference: Common Operations

```bash
# Start
./start.sh

# Stop (keeps volumes)
docker compose -f docker/docker-compose.yml down

# Stop + wipe data (destructive)
docker compose -f docker/docker-compose.yml down --volumes

# Rebuild after upstream changes
git pull
USER_UID=$(id -u) USER_GID=$(id -g) docker compose -f docker/docker-compose.yml up --build -d

# Tail logs
docker compose -f docker/docker-compose.yml logs -f server

# Connect to postgres directly
docker compose -f docker/docker-compose.yml exec db psql -U paperclip -d paperclip
```
