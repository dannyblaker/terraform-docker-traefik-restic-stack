#!/bin/bash
set -euo pipefail

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}"
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD:-$(cat ./restic_password.txt)}"

echo "Getting credentials from EC2 metadata (optional)"
IMDS="http://<IP>"
TOKEN=$(curl -sS -X PUT "$IMDS/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
if [[ -n "${TOKEN:-}" ]]; then
  ROLE=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/latest/meta-data/iam/security-credentials/" || true)
  if [[ -n "${ROLE:-}" ]]; then
    CREDS=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/latest/meta-data/iam/security-credentials/$ROLE" || true)
    export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
    export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .Token)
  fi
fi

BACKUP_DIR="./backup_volumes"

# (Assuming you've already run: restic restore latest --target backup_volumes)
for BACKUP_FILE in "$BACKUP_DIR"/*.tgz; do
  VOLUME_NAME=$(basename "$BACKUP_FILE" .tgz)
  echo "Restoring volume $VOLUME_NAME..."
  if ! docker volume ls -q | grep -w "$VOLUME_NAME" >/dev/null; then
    docker volume create "$VOLUME_NAME"
  fi
  docker run --rm -v "$VOLUME_NAME":/data -v "$BACKUP_DIR":/backup alpine \
    tar xzf /backup/"$VOLUME_NAME".tgz -C /data
  echo "Restoration of $VOLUME_NAME completed."
done

echo "All volumes have been restored."
