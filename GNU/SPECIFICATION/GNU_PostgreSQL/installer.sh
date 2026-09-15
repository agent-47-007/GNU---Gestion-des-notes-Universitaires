#!/usr/bin/env bash
# GNU : installation initiale dans une base PostgreSQL 14+.
set -Eeuo pipefail
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
creer_base=false
lancer_tests=false
for arg in "$@"; do
  case "$arg" in
    --create-db) creer_base=true ;;
    --tests) lancer_tests=true ;;
    -h|--help)
      cat <<'HELP'
Usage : bash installer.sh [--create-db] [--tests]
Connexion : PGHOST, PGPORT, PGUSER, PGDATABASE (défaut gnu_notes).
Authentification : .pgpass ou invite psql; aucun mot de passe dans ce script.
--create-db : crée la base (échoue si elle existe).
--tests     : exécute les tests transactionnels après installation.
GNU_APP_ROLE : rôle PostgreSQL existant réservé à Laravel (facultatif).
L’installation refuse un schéma gnu déjà présent et ne supprime aucune base.
HELP
      exit 0 ;;
    *) printf 'Argument inconnu : %s\n' "$arg" >&2; exit 2 ;;
  esac
done
command -v psql >/dev/null || { echo 'Client psql absent. Installer postgresql-client.' >&2; exit 127; }
export PGDATABASE="${PGDATABASE:-gnu_notes}"
if "$creer_base"; then
  command -v createdb >/dev/null || { echo 'Commande createdb absente.' >&2; exit 127; }
  createdb --maintenance-db="${GNU_MAINTENANCE_DB:-postgres}" -- "$PGDATABASE"
fi
version_num="$(psql -X -A -t -v ON_ERROR_STOP=1 -c 'SHOW server_version_num')"
if [[ ! "$version_num" =~ ^[0-9]+$ ]] || (( version_num < 140000 )); then
  echo 'PostgreSQL 14 ou supérieur est requis.' >&2; exit 2
fi
printf 'Installation GNU dans la base %s\n' "$PGDATABASE"
psql -X -v ON_ERROR_STOP=1 -f "$base_dir/001_creation.sql"
if "$lancer_tests"; then
  psql -X -v ON_ERROR_STOP=1 -f "$base_dir/002_tests.sql"
fi
if [[ -n "${GNU_APP_ROLE:-}" ]]; then
  psql -X -v ON_ERROR_STOP=1 -v app_role="$GNU_APP_ROLE" -f "$base_dir/003_droits.sql"
fi
printf 'Installation terminée. Schéma : gnu.\n'
