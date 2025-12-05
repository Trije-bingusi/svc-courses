#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/azure.env}"
source "$ENV_FILE"

# Platforms for AKS (arm64 on our cluster).
PLATFORMS="${PLATFORMS:-linux/arm64}"

# floating tag to keep updated
FLOATING_TAG="${FLOATING_TAG:-dev}"

# If IMAGE_TAG not set, create an immutable timestamp tag
IMAGE_TAG="${IMAGE_TAG:-${FLOATING_TAG}-$(date +%Y%m%d%H%M%S)}"

# azure login / ensure acr
if [[ -n "${SUBSCRIPTION:-}" ]]; then
  echo "Setting subscription: $SUBSCRIPTION"
  az account set --subscription "$SUBSCRIPTION"
fi

echo "RG=$RG LOC=$LOC ACR=$ACR IMAGE=${IMAGE_NAME}:${IMAGE_TAG} PLATFORMS=$PLATFORMS"

az group show -n "$RG" >/dev/null 2>&1 || az group create -n "$RG" -l "$LOC" >/dev/null
if ! az acr show -n "$ACR" -g "$RG" >/dev/null 2>&1; then
  echo "Creating ACR $ACR in $LOC (Basic SKU)…"
  az acr create -n "$ACR" -g "$RG" --sku Basic --location "$LOC" >/dev/null
fi

LOGIN_SERVER="$(az acr show -n "$ACR" --query loginServer -o tsv)"
az acr login -n "$ACR" >/dev/null

# buildx setup
if ! docker buildx inspect multiarch >/dev/null 2>&1; then
  docker buildx create --use --name multiarch >/dev/null
else
  docker buildx use multiarch >/dev/null
fi

# build & push
cd "$REPO_ROOT"

echo "Building & pushing:"
echo "  ${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  ${LOGIN_SERVER}/${IMAGE_NAME}:${FLOATING_TAG}"

docker buildx build \
  --platform "$PLATFORMS" \
  -t "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
  -t "${LOGIN_SERVER}/${IMAGE_NAME}:${FLOATING_TAG}" \
  --push \
  .

echo "Pushed:"
echo "  ${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  ${LOGIN_SERVER}/${IMAGE_NAME}:${FLOATING_TAG}"

echo
echo "Verify manifests:"
docker buildx imagetools inspect "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" | sed -n '/Platform/,$p'

# print digest
DIGEST="$(az acr repository show-manifests \
  --name "$ACR" \
  --repository "$IMAGE_NAME" \
  --query "[?contains(tags, '${IMAGE_TAG}')].digest | [0]" \
  -o tsv 2>/dev/null || true)"

if [[ -n "$DIGEST" ]]; then
  echo
  echo "Immutable digest for this build:"
  echo "${LOGIN_SERVER}/${IMAGE_NAME}@${DIGEST}"
fi

echo "Done."