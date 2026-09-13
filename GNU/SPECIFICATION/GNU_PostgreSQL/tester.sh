#!/usr/bin/env bash
set -Eeuo pipefail
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
command -v psql >/dev/null || { echo 'psql requis' >&2; exit 127; }
export PGDATABASE="${PGDATABASE:-gnu_notes}"
psql -X -v ON_ERROR_STOP=1 -f "$base_dir/002_tests.sql"
