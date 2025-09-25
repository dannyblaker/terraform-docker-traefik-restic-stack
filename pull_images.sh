#!/bin/bash
set -euo pipefail

FOLDER_PATHS=("n8n" "redis-n8n" "traefik")

for folder_path in "${FOLDER_PATHS[@]}"; do
  docker compose -f "./$folder_path/docker-compose.yml" pull
done
