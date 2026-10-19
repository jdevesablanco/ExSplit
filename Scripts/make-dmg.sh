#!/bin/bash
# build/ExSplit.app → build/ExSplit-<versión>.dmg (con acceso directo a Aplicaciones)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
[[ -d build/ExSplit.app ]] || Scripts/build-app.sh
STAGE="$(mktemp -d)"
cp -R build/ExSplit.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/LEEME - README.txt" <<'TXT'
ExSplit — arrastra ExSplit.app a Aplicaciones y ábrela.
Si macOS dice que no puede verificar la app: Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente».
(La app no está notarizada por Apple; es software libre y el código está en GitHub.)
TXT
rm -f "build/ExSplit-$VERSION.dmg"
hdiutil create -volname "ExSplit" -srcfolder "$STAGE" -ov -format UDZO "build/ExSplit-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
echo "✓ build/ExSplit-$VERSION.dmg"
