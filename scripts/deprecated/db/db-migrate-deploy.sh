#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/db.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

# Required
: "${PG_SERVER:?PG_SERVER is required in db.env}"
: "${DB_ADMIN_USER:?DB_ADMIN_USER is required in db.env}"
: "${DB_ADMIN_PASS:?DB_ADMIN_PASS is required in db.env}"
: "${DB_NAME:?DB_NAME is required in db.env}"

if [[ -z "${DATABASE_URL:-}" ]]; then
  # Derive FQDN if not provided
  FQDN="${FQDN:-"${PG_SERVER}.postgres.database.azure.com"}"
  ADMIN_USER_FOR_URL="${DB_ADMIN_USER}%40${PG_SERVER}"
  DATABASE_URL="postgres://${DB_ADMIN_USER}:${DB_ADMIN_PASS}@${FQDN}:5432/${DB_NAME}?sslmode=require"
fi

echo "Applying Prisma migrations to ${DB_NAME} on ${PG_SERVER}…"
export DATABASE_URL

# Run from repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Deploy committed migrations
npx prisma migrate deploy

echo "Migrations applied."
