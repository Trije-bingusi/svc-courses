#!/usr/bin/env bash
set -euo pipefail
source "${1:-azure.env}"

# cd to repo root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "RG=$RG LOC=$LOC ACR=$ACR IMAGE=${IMAGE_NAME}:${IMAGE_TAG}"

# Ensure RG exists
if ! az group show -n "$RG" >/dev/null 2>&1; then
  az group create -n "$RG" -l "$LOC" >/dev/null
fi

# Create ACR if missing
if ! az acr show -n "$ACR" -g "$RG" >/dev/null 2>&1; then
  az acr create -n "$ACR" -g "$RG" --sku Basic --location "$LOC"
fi

LOGIN_SERVER="$(az acr show -n "$ACR" --query loginServer -o tsv)"

docker build -t "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" .

az acr login -n "$ACR"
docker push "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Image pushed to ${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
