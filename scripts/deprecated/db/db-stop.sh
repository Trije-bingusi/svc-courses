#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/db.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

source "$ENV_FILE"

: "${SUBSCRIPTION:?SUBSCRIPTION is required in db.env}"
: "${RG:?RG is required in db.env}"
: "${PG_SERVER:?PG_SERVER is required in db.env}"

echo "Using subscription: $SUBSCRIPTION"
az account set --subscription "$SUBSCRIPTION" >/dev/null

if ! az postgres flexible-server show -g "$RG" -n "$PG_SERVER" >/dev/null 2>&1; then
  echo "Server '$PG_SERVER' not found in RG '$RG'." >&2
  exit 1
fi

STATE="$(az postgres flexible-server show -g "$RG" -n "$PG_SERVER" --query 'state' -o tsv)"
echo "Current state: $STATE"

if [[ "$STATE" == "Stopped" ]]; then
  echo "Server is already Stopped."
  exit 0
fi

echo "Stopping server '$PG_SERVER'..."
az postgres flexible-server stop -g "$RG" -n "$PG_SERVER" >/dev/null

echo -n "Waiting for state=Stopped"
for i in {1..60}; do
  STATE="$(az postgres flexible-server show -g "$RG" -n "$PG_SERVER" --query 'state' -o tsv 2>/dev/null || true)"
  if [[ "$STATE" == "Stopped" ]]; then
    echo
    echo "Server is Stopped."
    exit 0
  fi
  echo -n "."
  sleep 5
done

echo
echo "Timed out waiting for server to stop (last state: $STATE)" >&2
exit 1