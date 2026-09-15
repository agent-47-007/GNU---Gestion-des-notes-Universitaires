#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env.local ]]; then
  set -a
  source .env.local
  set +a
fi

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5435}"
export DB_NAME="${DB_NAME:-gnu_notes}"
export DB_USER="${DB_USER:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-}"

echo "GNU API → PostgreSQL ${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "API disponible sur http://127.0.0.1:${API_PORT:-8080}"
php -S "127.0.0.1:${API_PORT:-8080}" -t backend/public
