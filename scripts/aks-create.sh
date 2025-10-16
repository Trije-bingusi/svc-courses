#!/usr/bin/env bash
set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/aks.env}"
source "$ENV_FILE"

# Ensure correct subscription
if [[ -n "${SUBSCRIPTION:-}" ]]; then
  echo "Setting Azure subscription to: $SUBSCRIPTION"
  az account set --subscription "$SUBSCRIPTION"
fi
echo "Active subscription:"
az account show --query "{name:name,id:id,tenant:tenantId}" -o table

# Install kubectl if missing
az aks install-cli >/dev/null 2>&1 || true

# Create RG only if it does not exist
if ! az group show -n "$RG" >/dev/null 2>&1; then
  echo "Creating resource group: $RG ($LOC)"
  az group create -n "$RG" -l "$LOC" >/dev/null
fi

# Create AKS only if missing
if ! az aks show -n "$AKS" -g "$RG" >/dev/null 2>&1; then
  echo "Creating AKS: $AKS ($LOC) nodes=$NODE_COUNT size=$NODE_VM_SIZE"
  az aks create -n "$AKS" -g "$RG" \
    --location "$LOC" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    --enable-managed-identity
else
  echo "AKS '$AKS' already exists in RG '$RG' — skipping create"
fi

echo "Getting kubeconfig"
az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing

echo "Cluster is ready:"
kubectl cluster-info
kubectl get nodes -o wide