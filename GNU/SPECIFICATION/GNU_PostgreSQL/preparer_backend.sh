#!/usr/bin/env bash
# Compte PostgreSQL dédié à Laravel; les DDL sont exécutés par l'administrateur.
set -Eeuo pipefail
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
set_password=false
for arg in "$@"; do
  case "$arg" in
    --password) set_password=true ;;
    -h|--help)
      cat <<'HELP'
Usage : bash preparer_backend.sh [--password]
Provisionne gnu_app et la table Sanctum, après l'installation métier.
Connexion admin : PGHOST (localhost), PGPORT (5435), PGUSER (postgres).
Bases admises : gnu_notes (défaut), gnu_notes_test (recette isolée).
Authentification admin : .pgpass ou invite psql.
--password : ouvre ensuite l'invite masquée psql pour le mot de passe gnu_app.
Sans cette option, le rôle créé reste sans mot de passe jusqu'à configuration.
Le script ne lance aucune migration Laravel et ne stocke aucun secret.
HELP
      exit 0 ;;
    *) printf 'Argument inconnu : %s\n' "$arg" >&2; exit 2 ;;
  esac
done
command -v psql >/dev/null || { echo 'Client psql absent.' >&2; exit 127; }
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5435}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-gnu_notes}"
if [[ "$PGDATABASE" != 'gnu_notes' && "$PGDATABASE" != 'gnu_notes_test' ]]; then
  echo 'Ce provisionnement cible exclusivement gnu_notes ou gnu_notes_test.' >&2
  exit 2
fi
psql -X -v ON_ERROR_STOP=1 -f "$base_dir/004_backend_laravel.sql"
if "$set_password"; then
  # \password chiffre le secret avant envoi; ne jamais remplacer par une
  # commande ALTER ROLE contenant le mot de passe dans le shell ou les logs.
  psql -X -v ON_ERROR_STOP=1 -c "SET password_encryption = 'scram-sha-256'" -c '\password gnu_app'
fi
printf 'Provisionnement terminé pour gnu_app dans %s (port %s).\n' "$PGDATABASE" "$PGPORT"
