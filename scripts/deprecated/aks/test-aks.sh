#!/usr/bin/env bash
set -euo pipefail

# Resolve pathse
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/aks.env}"
source "$ENV_FILE"

if [[ -n "${SUBSCRIPTION:-}" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

echo "Subscription:"
az account show --query "{name:name,id:id,tenant:tenantId}" -o table
echo

# Quick existence checks
if ! az group show -n "$RG" >/dev/null 2>&1; then
  echo "Resource group '$RG' not found."
  exit 1
fi

if ! az aks show -n "$AKS" -g "$RG" >/dev/null 2>&1; then
  echo "AKS cluster '$AKS' not found in RG '$RG'."
  exit 1
fi

# Gather cluster info
STATE=$(az aks show -n "$AKS" -g "$RG" --query "powerState.code" -o tsv 2>/dev/null || echo "Unknown")
PROV=$(az aks show -n "$AKS" -g "$RG" --query "provisioningState" -o tsv)
K8S=$(az aks show -n "$AKS" -g "$RG" --query "currentKubernetesVersion" -o tsv)
LOCN=$(az aks show -n "$AKS" -g "$RG" --query "location" -o tsv)
NODES=$(az aks show -n "$AKS" -g "$RG" --query "agentPoolProfiles[0].count" -o tsv)
SIZE=$(az aks show -n "$AKS" -g "$RG" --query "agentPoolProfiles[0].vmSize" -o tsv)
FQDN=$(az aks show -n "$AKS" -g "$RG" --query "fqdn" -o tsv)

echo "AKS Overview"
echo "------------"
printf "Name:        %s\n" "$AKS"
printf "Resource RG: %s\n" "$RG"
printf "Location:    %s\n" "$LOCN"
printf "K8s Ver:     %s\n" "$K8S"
printf "Nodes:       %s\n" "${NODES:-?}"
printf "VM Size:     %s\n" "${SIZE:-?}"
printf "State:       %s\n" "$STATE"
printf "FQDN:        %s\n" "${FQDN:-N/A}"
printf "ProvState:   %s\n" "$PROV"
echo

# If running, try to connect and show node status
if [[ "$STATE" == "Running" ]]; then
  echo "Fetching kubeconfig and checking nodes…"
  az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing >/dev/null
  if command -v kubectl >/dev/null 2>&1; then
    kubectl cluster-info
    echo
    kubectl get nodes -o wide
  else
    echo "kubectl not installed on this machine."
  fi
else
  echo "Cluster is not running. Start it with:"
  echo "az aks start -n \"$AKS\" -g \"$RG\""
fi
