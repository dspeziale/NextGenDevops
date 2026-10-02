#!/usr/bin/env bash
# Deploy (o rollback) di una versione su Coolify via API.
#   export COOLIFY_URL=http://10.20.23.64:8000
#   export COOLIFY_TOKEN=...          # Coolify > Keys & Tokens > API tokens
#   export COOLIFY_APP_UUID=...       # UUID della risorsa NextGenDevops in Coolify
#   ./scripts/deploy.sh 1.1.0         # aggiorna
#   ./scripts/deploy.sh 1.0.1         # rollback
set -euo pipefail

VERSION="${1:?Uso: $0 X.Y.Z}"
: "${COOLIFY_URL:?imposta COOLIFY_URL}"
: "${COOLIFY_TOKEN:?imposta COOLIFY_TOKEN}"
: "${COOLIFY_APP_UUID:?imposta COOLIFY_APP_UUID}"

API="$COOLIFY_URL/api/v1"
AUTH=(-H "Authorization: Bearer $COOLIFY_TOKEN" -H "Content-Type: application/json")

echo "Imposto sorgente = tag v$VERSION"
curl -fsS -X PATCH "${AUTH[@]}" "$API/applications/$COOLIFY_APP_UUID" -d "{\"git_branch\":\"v$VERSION\"}" >/dev/null

echo "Imposto APP_VERSION=$VERSION"
curl -fsS -X PATCH "${AUTH[@]}" "$API/applications/$COOLIFY_APP_UUID/envs" \
  -d "{\"key\":\"APP_VERSION\",\"value\":\"$VERSION\"}" >/dev/null

echo "Avvio deploy"
curl -fsS -X POST "${AUTH[@]}" "$API/deploy?uuid=$COOLIFY_APP_UUID&force=false"
echo
