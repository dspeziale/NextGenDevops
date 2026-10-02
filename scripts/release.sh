#!/usr/bin/env bash
# Crea una nuova versione: ./scripts/release.sh 1.1.0
# Aggiorna CHANGELOG/VERSION, crea il tag vX.Y.Z e lo pusha -> GitHub Actions builda l'immagine.
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Uso: $0 X.Y.Z   (versione attuale: $(cat VERSION))" >&2
  exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Il tag v$VERSION esiste gia'" >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Ci sono modifiche non committate: committale prima del rilascio" >&2
  exit 1
fi

echo "$VERSION" > VERSION
git add VERSION
git diff --cached --quiet || git commit -m "release: v$VERSION"
git tag -a "v$VERSION" -m "Release v$VERSION"
git push origin HEAD
git push origin "v$VERSION"

echo "Tag v$VERSION pushato. Segui la build su GitHub > Actions, poi deploya con:"
echo "  ./scripts/deploy.sh $VERSION"
