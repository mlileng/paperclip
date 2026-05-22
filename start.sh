#!/bin/bash
set -e
cd "$(dirname "$0")"
USER_UID=$(id -u) USER_GID=$(id -g) \
  docker compose --env-file .env -f docker/docker-compose.yml up -d
echo "Paperclip running at http://localhost:3100"
echo "Logs:  docker compose --env-file .env -f docker/docker-compose.yml logs -f"
echo "Stop:  docker compose --env-file .env -f docker/docker-compose.yml down"
