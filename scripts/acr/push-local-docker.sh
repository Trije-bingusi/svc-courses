#!/usr/bin/env bash
set -euo pipefail

# Resolve paths first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"          # repo root
ENV_FILE="${1:-$SCRIPT_DIR/azure.env}"               # default to scripts/acr/azure.env
source "$ENV_FILE"

# Ensure right subscription
if [[ -n "${SUBSCRIPTION:-}" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

echo "RG=$RG LOC=$LOC ACR=$ACR IMAGE=${IMAGE_NAME}:${IMAGE_TAG}"

# Ensure RG
if ! az group show -n "$RG" >/dev/null 2>&1; then
  az group create -n "$RG" -l "$LOC" >/dev/null
fi

# Ensure ACR
if ! az acr show -n "$ACR" -g "$RG" >/dev/null 2>&1; then
  az acr create -n "$ACR" -g "$RG" --sku Basic --location "$LOC" >/dev/null
fi

LOGIN_SERVER="$(az acr show -n "$ACR" --query loginServer -o tsv)"

# Build from repo root
cd "$REPO_ROOT"
docker build -t "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" .

# Push
az acr login -n "$ACR" >/dev/null
docker push "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Image pushed: ${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
