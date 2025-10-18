#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-rso}"
HOST="${HOST:-courses.localtest.me}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Ensure kube context
if [[ -f "$SCRIPT_DIR/aks.env" ]]; then
  source "$SCRIPT_DIR/aks.env"
  [[ -n "${SUBSCRIPTION:-}" ]] && az account set --subscription "$SUBSCRIPTION"
  az aks get-credentials -n "$AKS" -g "$RG" --overwrite-existing >/dev/null
  # Make sure AKS can pull ACR images
  [[ -n "${ACR:-}" ]] && az aks update -n "$AKS" -g "$RG" --attach-acr "$ACR" >/dev/null
fi

echo "Using namespace: $NS"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

# Apply the real DB Secret from scripts/db/db.env
if [[ -f "$ROOT/scripts/db/db-secret.sh" ]]; then
  echo "Applying DB Secret from scripts/db/db.env"
  bash "$ROOT/scripts/db/db-secret.sh"
else
  echo "ERROR: scripts/db/db-secret.sh not found." >&2
  exit 1
fi

# Apply manifests (namespace, service, deployment, ingress)
cd "$ROOT"
echo "Applying manifests"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress.yaml || true

# Rollout (wait to allow image pull + DB connect)
echo "Waiting for rollout (svc-courses)"
set +e
kubectl -n "$NS" rollout status deploy/svc-courses --timeout=240s
ROLLOUT_RC=$?
set -e
if [[ $ROLLOUT_RC -ne 0 ]]; then
  echo "Rollout did not finish in time. Showing pods:"
  kubectl -n "$NS" get pods -o wide
  echo "Recent pod events:"
  kubectl -n "$NS" describe pod -l app=svc-courses | sed -n '/Events:/,$p' || true
fi

# Resolve Ingress external IP
echo "Resolving Ingress controller External IP"
for i in {1..40}; do
  INGRESS_IP="$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [[ -n "$INGRESS_IP" ]] && break
  sleep 3
done

if [[ -z "${INGRESS_IP:-}" ]]; then
  echo "Ingress not ready — using port-forward fallback."
  kubectl -n "$NS" port-forward svc/svc-courses 3000:80 >/dev/null 2>&1 &
  PF_PID=$!
  sleep 2

  echo "Smoke tests (port-forward)"
  echo "GET http://localhost:3000/healthz"
  curl -sS -D - http://localhost:3000/healthz || true
  echo

  echo "Create a course via POST"
  curl -sS -D - -H "Content-Type: application/json" \
    -X POST -d '{"name":"AKS Smoke Test"}' \
    http://localhost:3000/api/courses || true
  echo

  echo "List courses"
  curl -sS -D - http://localhost:3000/api/courses || true
  echo

  kill $PF_PID >/dev/null 2>&1 || true
  exit 0
fi

# Test through Ingress
echo "Smoke tests (Ingress $INGRESS_IP; Host=$HOST)"
echo "GET /healthz"
curl -sS -D - -H "Host: ${HOST}" "http://${INGRESS_IP}/healthz" || true
echo

echo "POST /api/courses"
curl -sS -D - -H "Host: ${HOST}" -H "Content-Type: application/json" \
  -X POST -d '{"name":"AKS Smoke Test"}' \
  "http://${INGRESS_IP}/api/courses" || true
echo

echo "GET /api/courses"
curl -sS -D - -H "Host: ${HOST}" \
  "http://${INGRESS_IP}/api/courses" || true
echo

echo "Done."
