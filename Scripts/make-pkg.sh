#!/bin/bash
# build/ExSplit.app → build/ExSplit-<versión>.pkg (instala en /Applications y abre la configuración inicial)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
[[ -d build/ExSplit.app ]] || Scripts/build-app.sh
W="$(mktemp -d)"
mkdir -p "$W/root" "$W/scripts"
cp -R build/ExSplit.app "$W/root/"
cat > "$W/scripts/postinstall" <<'SH'
#!/bin/bash
# Abre la app como el usuario con la sesión iniciada (el instalador corre como root).
U="$(stat -f%Su /dev/console)"
[ -n "$U" ] && [ "$U" != "root" ] && sudo -u "$U" open -a /Applications/ExSplit.app || true
exit 0
SH
chmod +x "$W/scripts/postinstall"
pkgbuild --root "$W/root" --scripts "$W/scripts" --identifier io.github.jdevesablanco.ExSplit.pkg \
  --version "$VERSION" --install-location /Applications "$W/ExSplit-component.pkg" >/dev/null
cat > "$W/dist.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>ExSplit</title>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <choices-outline><line choice="default"><line choice="app"/></line></choices-outline>
  <choice id="default"/>
  <choice id="app" visible="false"><pkg-ref id="io.github.jdevesablanco.ExSplit.pkg"/></choice>
  <pkg-ref id="io.github.jdevesablanco.ExSplit.pkg" version="$VERSION" onConclusion="none">ExSplit-component.pkg</pkg-ref>
</installer-gui-script>
XML
rm -f "build/ExSplit-$VERSION.pkg"
productbuild --distribution "$W/dist.xml" --package-path "$W" "build/ExSplit-$VERSION.pkg" >/dev/null
rm -rf "$W"
echo "✓ build/ExSplit-$VERSION.pkg"
