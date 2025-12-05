#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/aks.env}"
COUNT="${2:-2}"  # default 2
source "$ENV_FILE"

[[ -n "${SUBSCRIPTION:-}" ]] && az account set --subscription "$SUBSCRIPTION"

echo "Scaling AKS '$AKS' in RG '$RG' to $COUNT node(s)…"
az aks scale -n "$AKS" -g "$RG" --node-count "$COUNT"
az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing >/dev/null
kubectl get nodes -o wide