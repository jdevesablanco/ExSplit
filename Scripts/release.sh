#!/bin/bash
# Uso: Scripts/release.sh 1.0.1
# 1) sube versión a la fórmula y la CLI  2) crea el tag y lo empuja  3) rellena el sha256 de la fórmula del tap.
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:?uso: Scripts/release.sh X.Y.Z}"
sed -i '' "s|archive/refs/tags/v[0-9.]*\.tar\.gz|archive/refs/tags/v$V.tar.gz|" homebrew/Formula/exsplit.rb
sed -i '' "s|version \"[0-9.]*\"|version \"$V\"|" homebrew/Casks/exsplit.rb
sed -i '' "s|exsplit [0-9.]*\")|exsplit $V\")|" Sources/ExSplitCLI/main.swift
sed -i '' "s|static let version = \"[0-9.]*\"|static let version = \"$V\"|" Sources/ExSplitApp/Titles.swift
git add -A && git commit -m "Release v$V" && git tag "v$V" && git push origin main "v$V"
echo "Esperando al tarball de GitHub…"; sleep 8
SHA="$(curl -sL "https://github.com/jdevesablanco/ExSplit/archive/refs/tags/v$V.tar.gz" | shasum -a 256 | cut -d' ' -f1)"
sed -i '' "s|sha256 \"[0-9a-fA-FREPLACE_WITH_SHA256_]*\"|sha256 \"$SHA\"|" homebrew/Formula/exsplit.rb
echo "sha256 = $SHA"
echo "Copia homebrew/Formula/exsplit.rb a tu repo jdevesablanco/homebrew-tap (Formula/) y haz push."
echo "(La CI ya habrá publicado el DMG en la release v$V.)"
