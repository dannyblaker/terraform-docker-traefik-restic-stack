#!/bin/bash

# Define an array of folder paths
FOLDER_PATHS=("traefik" "n8n" "redis-n8n")

# Iterate through the list
for folder_path in "${FOLDER_PATHS[@]}"; do

    docker compose -f "./$folder_path/docker-compose.yml" down

done
