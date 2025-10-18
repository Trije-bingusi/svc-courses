#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks.env"

[[ -n "${SUBSCRIPTION:-}" ]] && az account set --subscription "$SUBSCRIPTION"

# Ensure kubeconfig and wait until API responds + nodes are Ready
az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing >/dev/null

echo "Waiting for API server to be reachable…"
for i in {1..30}; do
  if kubectl version --short >/dev/null 2>&1; then
    break
  fi
  sleep 4
done

echo "Waiting for nodes to be Ready…"
for i in {1..30}; do
  NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2!="Ready"{print $1}' | wc -l | tr -d ' ')
  if [[ "${NOT_READY:-0}" == "0" ]]; then
    break
  fi
  sleep 4
done

# Install NGINX Ingress Controller (LoadBalancer)
kubectl create namespace ingress-nginx 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.publishService.enabled=true \
  --set controller.metrics.enabled=true \
  --set controller.service.type=LoadBalancer

echo "Waiting for Ingress controller EXTERNAL-IP…"
for i in {1..40}; do
  IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$IP" ]]; then
    echo "Ingress LB IP: $IP"
    exit 0
  fi
  sleep 5
done

echo "Timeout waiting for Ingress external IP."
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide || true
exit 1
