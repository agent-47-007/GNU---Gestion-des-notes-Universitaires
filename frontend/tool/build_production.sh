#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GNU_API_BASE_URL:-}" ]]; then
  printf '%s\n' 'GNU_API_BASE_URL est obligatoire pour une build de production.' >&2
  exit 2
fi

case "$GNU_API_BASE_URL" in
  https://?*/api/v1|https://?*/api/v1/) ;;
  *)
    printf '%s\n' 'GNU_API_BASE_URL doit être une URL HTTPS terminée par /api/v1.' >&2
    exit 2
    ;;
esac

authority="${GNU_API_BASE_URL#https://}"
authority="${authority%%/*}"
host="${authority%%:*}"
api_path="${GNU_API_BASE_URL#https://$authority}"
if [[ -z "$authority" || "$authority" == *@* || "$GNU_API_BASE_URL" == *[[:space:]]* || "$GNU_API_BASE_URL" == *\?* || "$GNU_API_BASE_URL" == *\#* || ! "$api_path" =~ ^/api/v1/?$ || "$host" == 'localhost' || "$host" == '127.0.0.1' || "$host" == '::1' || "$authority" == '[::1]' || "$authority" == '[::1]:'* ]]; then
  printf '%s\n' 'GNU_API_BASE_URL contient une autorité ou un chemin invalide.' >&2
  exit 2
fi

exec flutter build web --release --no-pub --no-wasm-dry-run \
  --dart-define="GNU_API_BASE_URL=$GNU_API_BASE_URL"
