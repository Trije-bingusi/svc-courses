#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/db.env}"

[[ -f "$ENV_FILE" ]] || { echo "Env file not found: $ENV_FILE"; exit 1; }
source "$ENV_FILE"

NS="${K8S_NAMESPACE:-rso}"
SECRET_NAME="${K8S_DB_SECRET:-db-credentials}"

: "${PG_SERVER:?PG_SERVER is required in db.env}"
: "${DB_ADMIN_USER:?DB_ADMIN_USER is required in db.env}"
: "${DB_ADMIN_PASS:?DB_ADMIN_PASS is required in db.env}"
: "${DB_NAME:?DB_NAME is required in db.env}"

if [[ -z "${DATABASE_URL:-}" ]]; then
  DATABASE_URL="postgres://${DB_ADMIN_USER}:${DB_ADMIN_PASS}@${PG_SERVER}.postgres.database.azure.com:5432/${DB_NAME}?sslmode=require"
fi

echo "Ensuring namespace '$NS' exists…"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS" >/dev/null

echo "Writing Secret '$SECRET_NAME' in namespace '$NS'…"
kubectl -n "$NS" create secret generic "$SECRET_NAME" \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret applied."
