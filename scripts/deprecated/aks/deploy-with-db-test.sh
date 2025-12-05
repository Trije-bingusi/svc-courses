#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-rso}"
HOST="${HOST:-courses.localtest.me}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

#  Kube context + ACR attach (idempotent)
if [[ -f "$SCRIPT_DIR/aks.env" ]]; then
  source "$SCRIPT_DIR/aks.env"
  [[ -n "${SUBSCRIPTION:-}" ]] && az account set --subscription "$SUBSCRIPTION"
  az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing >/dev/null
  [[ -n "${ACR:-}" ]] && az aks update -n "$AKS" -g "$RG" --attach-acr "$ACR" >/dev/null
fi

echo "Using namespace: $NS"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null

# DB secret (from scripts/db/db.env)
if [[ -f "$ROOT/scripts/db/db-secret.sh" ]]; then
  echo "Applying DB Secret from scripts/db/db.env"
  bash "$ROOT/scripts/db/db-secret.sh"
else
  echo "ERROR: scripts/db/db-secret.sh not found." >&2
  exit 1
fi

# Apply app manifests
cd "$ROOT"
echo "Applying manifests"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress.yaml || true

# Wait for Deployment rollout
echo "Waiting for rollout (svc-courses)"
if ! kubectl -n "$NS" rollout status deploy/svc-courses --timeout=240s; then
  echo "Rollout timed out. Pods:"
  kubectl -n "$NS" get pods -o wide
  echo "Recent events:"
  kubectl -n "$NS" describe pod -l app=svc-courses | sed -n '/Events:/,$p' || true
  exit 1
fi

# Cluster-local smoke tests
# Hit the Service DNS from a temporary pod in the same namespace
echo "Cluster-local test via Service DNS (svc-courses.${NS}.svc.cluster.local)"
kubectl -n "$NS" run curl-svc --rm -it --image=alpine --restart=Never -- \
  sh -lc '
    set -e
    apk add --no-cache curl >/dev/null
    echo "GET /healthz";          curl -sS svc-courses/healthz; echo
    echo "GET /api/courses";      curl -sS svc-courses/api/courses; echo
  '

# Hit the Ingress controller inside the cluster with Host header
echo "Cluster-local test through Ingress controller service with Host=${HOST}"
kubectl -n "$NS" run curl-ing --rm -it --image=alpine --restart=Never -- \
  sh -lc '
    set -e
    apk add --no-cache curl >/dev/null
    INGRESS_DNS="ingress-nginx-controller.ingress-nginx.svc.cluster.local"
    echo "GET /healthz via Ingress";     curl -sS -H "Host: '"$HOST"'" "http://${INGRESS_DNS}/healthz"; echo
    echo "GET /api/courses via Ingress"; curl -sS -H "Host: '"$HOST"'" "http://${INGRESS_DNS}/api/courses"; echo
  '

echo "Done."
