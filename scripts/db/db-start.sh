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

if [[ "$STATE" != "Ready" ]]; then
  echo "Starting server '$PG_SERVER'..."
  az postgres flexible-server start -g "$RG" -n "$PG_SERVER" >/dev/null
fi

echo -n "Waiting for state=ready"
for i in {1..60}; do
  STATE="$(az postgres flexible-server show -g "$RG" -n "$PG_SERVER" --query 'state' -o tsv 2>/dev/null || true)"
  if [[ "$STATE" == "Ready" ]]; then
    echo
    echo "Server is ready."
    break
  fi
  echo -n "."
  sleep 5
done

if [[ "$STATE" != "Ready" ]]; then
  echo
  echo "Timed out waiting for server to become ready (last state: $STATE)" >&2
  exit 1
fi

# Add firewall rule for the caller's current IP
if [[ "${ADD_MY_IP:-0}" == "1" ]]; then
  if command -v curl >/dev/null 2>&1; then
    MYIP="$(curl -s https://ipinfo.io/ip || true)"
    if [[ -n "$MYIP" ]]; then
      RULE="dev-${MYIP//./-}"
      echo "Adding/Updating firewall rule '$RULE' for IP: $MYIP"
      az postgres flexible-server firewall-rule create \
        -g "$RG" -n "$PG_SERVER" \
        --rule-name "$RULE" \
        --start-ip-address "$MYIP" \
        --end-ip-address "$MYIP" >/dev/null || true
    else
      echo "Could not detect public IP; skipping firewall rule."
    fi
  else
    echo "curl not found; skipping firewall rule."
  fi
fi

# Show connection info
FQDN="${FQDN:-"${PG_SERVER}.postgres.database.azure.com"}"
echo
echo "Connection host: $FQDN"
if [[ -n "${DB_ADMIN_USER:-}" && -n "${DB_ADMIN_PASS:-}" && -n "${DB_NAME:-}" ]]; then
  echo "DATABASE_URL (example):"
  echo "postgres://${DB_ADMIN_USER}:${DB_ADMIN_PASS}@${FQDN}:5432/${DB_NAME}?sslmode=require"
fi
