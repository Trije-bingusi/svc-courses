#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/azure.env}"
source "$ENV_FILE"

if [[ -n "${SUBSCRIPTION:-}" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

LOGIN_SERVER="$(az acr show -n "$ACR" --query loginServer -o tsv)"

echo "Result"
echo "-----------"
echo "$IMAGE_NAME"

echo "Result"
echo "--------"
echo "$IMAGE_TAG"

echo
echo "Pull test:"
docker pull "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo
echo "Repositories:"
az acr repository list -n "$ACR" -o table

echo
echo "Tags for $IMAGE_NAME:"
az acr repository show-tags -n "$ACR" --repository "$IMAGE_NAME" -o table
