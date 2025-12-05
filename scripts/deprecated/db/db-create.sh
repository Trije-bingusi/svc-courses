#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/db.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

: "${SUBSCRIPTION:?SUBSCRIPTION is required in db.env}"
: "${RG:?RG is required in db.env}"
: "${LOC:?LOC is required in db.env}"
: "${PG_SERVER:?PG_SERVER is required in db.env}"
: "${DB_ADMIN_USER:?DB_ADMIN_USER is required in db.env}"
: "${DB_ADMIN_PASS:?DB_ADMIN_PASS is required in db.env}"
: "${DB_NAME:?DB_NAME is required in db.env}"
: "${PG_TIER:?PG_TIER is required in db.env}"       
: "${PG_SKU:?PG_SKU is required in db.env}"                
: "${PG_STORAGE_GB:?PG_STORAGE_GB is required in db.env}"  
: "${PG_VERSION:?PG_VERSION is required in db.env}"        

echo "Creating PostgreSQL Flexible Server ${PG_SERVER}…"

az account set --subscription "$SUBSCRIPTION" >/dev/null

# resource group
if ! az group show -n "$RG" >/dev/null 2>&1; then
  echo "Creating resource group '$RG' in '$LOC'…"
  az group create -n "$RG" -l "$LOC" >/dev/null
fi

# create server (idempotent)
if ! az postgres flexible-server show -g "$RG" -n "$PG_SERVER" >/dev/null 2>&1; then
  echo "Creating server '$PG_SERVER' in '$LOC' (tier=$PG_TIER, sku=$PG_SKU, storage=${PG_STORAGE_GB}GB)…"
  # --public-access 0.0.0.0 sets the "Allow Azure services"
  az postgres flexible-server create \
    --resource-group "$RG" \
    --name "$PG_SERVER" \
    --location "$LOC" \
    --version "$PG_VERSION" \
    --tier "$PG_TIER" \
    --sku-name "$PG_SKU" \
    --storage-size "$PG_STORAGE_GB" \
    --admin-user "$DB_ADMIN_USER" \
    --admin-password "$DB_ADMIN_PASS" \
    --public-access 0.0.0.0 \
    --yes >/dev/null
else
  echo "Server '$PG_SERVER' already exists — skipping create."
fi

# current public IP as a firewall rule (handy for local dev)
MY_IP="$(curl -s https://ipinfo.io/ip || true)"
if [[ -n "$MY_IP" ]]; then
  RULE_NAME="dev-${MY_IP//./-}"  # only letters/digits/_- allowed
  echo "Adding firewall rule for your IP ${MY_IP} (${RULE_NAME})…"
  az postgres flexible-server firewall-rule create \
    --resource-group "$RG" \
    --name "$PG_SERVER" \
    --rule-name "$RULE_NAME" \
    --start-ip-address "$MY_IP" \
    --end-ip-address "$MY_IP" >/dev/null || true
fi

# ensure DB exists
if ! az postgres flexible-server db show -g "$RG" -s "$PG_SERVER" -d "$DB_NAME" >/dev/null 2>&1; then
  echo "Creating database '${DB_NAME}'…"
  az postgres flexible-server db create \
    --resource-group "$RG" \
    --server-name "$PG_SERVER" \
    --database-name "$DB_NAME" >/dev/null
else
  echo "Database '${DB_NAME}' already exists — skipping create."
fi

# Output connection string
FQDN="$(az postgres flexible-server show -g "$RG" -n "$PG_SERVER" --query fullyQualifiedDomainName -o tsv)"
# admin user must be user@server in URL
ADMIN_USER_FOR_URL="${DB_ADMIN_USER}%40${PG_SERVER}"
DATABASE_URL="postgres://${ADMIN_USER_FOR_URL}:${DB_ADMIN_PASS}@${FQDN}:5432/${DB_NAME}?sslmode=require"

echo "Azure PostgreSQL ready."
echo "FQDN: ${FQDN}"
echo "DATABASE_URL (use in local .env / K8s Secret):"
echo "${DATABASE_URL}"