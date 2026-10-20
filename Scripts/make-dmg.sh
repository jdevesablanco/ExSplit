#!/bin/bash
# build/SplitExercises.app → build/SplitExercises-<versión>.dmg (con acceso directo a Aplicaciones)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
[[ -d build/SplitExercises.app ]] || Scripts/build-app.sh
STAGE="$(mktemp -d)"
cp -R build/SplitExercises.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/LEEME - README.txt" <<'TXT'
SplitExercises — arrastra SplitExercises.app a Aplicaciones y ábrela.
Si macOS dice que no puede verificar la app: Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente».
(La app no está notarizada por Apple; es software libre y el código está en GitHub.)
TXT
rm -f "build/SplitExercises-$VERSION.dmg"
hdiutil create -volname "SplitExercises" -srcfolder "$STAGE" -ov -format UDZO "build/SplitExercises-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
echo "✓ build/SplitExercises-$VERSION.dmg"
