#!/bin/bash
set -euo pipefail

docker network create my_network >/dev/null 2>&1 || true

FOLDER_PATHS=("traefik" "n8n" "redis-n8n")

for folder_path in "${FOLDER_PATHS[@]}"; do
  docker compose -f "./$folder_path/docker-compose.yml" pull
  docker compose -f "./$folder_path/docker-compose.yml" down
  docker compose -f "./$folder_path/docker-compose.yml" up -d
done
