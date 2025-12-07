#!/usr/bin/env bash
# =====================================================================
# Script: deploy.sh
# Description: Deploys the svc-courses application to Kubernetes,
#              retrieving configuration from the Key Vault identified
#              by the KEYVAULT_NAME env variable. The image to deploy
#              should be passed as a positional argument.
# Usage: ./scripts/deploy/deploy.sh <image>
# =====================================================================

# Retrieve image
IMAGE="$1"
if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image>" >&2
  exit 1
fi

# Retrieve configuration from the Key Vault
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config.sh"
RG_NAME=$(get_secret "rg-name")
AKS_NAME=$(get_secret "aks-name")
PG_NAME=$(get_secret "pg-name")
PG_FQDN=$(get_secret "pg-fqdn")
PG_USER=$(get_secret "pg-admin-username")
PG_PASS=$(get_secret "pg-admin-password")

# Configure the database URL secret in Kubernetes cluster
echo "Configuring database secret in Kubernetes namespace '$K8S_NAMESPACE'"
DB_URL="postgres://${PG_USER}:${PG_PASS}@${PG_FQDN}:5432/${DB_NAME}?sslmode=require"
kubectl create secret generic "$DB_SECRET" \
  --namespace "$K8S_NAMESPACE" \
  --from-literal=DATABASE_URL="$DB_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

# Authenticate to the AKS cluster
source "$SCRIPT_DIR/../utils/authenticate.sh"

# Deploy or upgrade the Helm chart
echo "Deploying Helm chart to namespace '$K8S_NAMESPACE' with image '$IMAGE'"
helm upgrade --install "$RELEASE_NAME" ./helm \
  --namespace "$K8S_NAMESPACE" \
  --values ./helm/values.yaml \
  --set image="$IMAGE" \
  --wait --timeout 5m
