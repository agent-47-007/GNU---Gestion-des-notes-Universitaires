#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/GNU/GNU_Backend"

if [[ -f "$ROOT_DIR/.env.local" ]]; then
    set -a
    source "$ROOT_DIR/.env.local"
    set +a
fi

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5435}"
export DB_DATABASE="${DB_DATABASE:-${DB_NAME:-gnu_notes}}"
export DB_USERNAME="${DB_USERNAME:-${DB_USER:-postgres}}"
export DB_PASSWORD="${DB_PASSWORD:-}"

API_PORT="${API_PORT:-8080}"

if [[ ! -f "$BACKEND_DIR/artisan" ]]; then
    echo "ERREUR : Laravel introuvable : $BACKEND_DIR/artisan"
    exit 1
fi

if [[ ! -f "$BACKEND_DIR/vendor/autoload.php" ]]; then
    echo "ERREUR : dépendances Composer absentes."
    echo "Exécute : cd GNU/GNU_Backend && composer install"
    exit 1
fi

echo "GNU API Laravel → PostgreSQL ${DB_HOST}:${DB_PORT}/${DB_DATABASE}"
echo "API disponible sur http://127.0.0.1:${API_PORT}"

cd "$BACKEND_DIR"

php artisan serve \
    --host=127.0.0.1 \
    --port="$API_PORT"
