# Alternativa binaria (DMG). Como la app no está notarizada por Apple, macOS pedirá «Abrir igualmente» la primera vez.
# Solo vale la pena publicarla si algún día notarizas el DMG (ver docs/NOTARIZATION.md) o si aceptas ese paso manual.
cask "exsplit" do
  version "1.0.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/jdevesablanco/ExSplit/releases/download/v#{version}/ExSplit-#{version}.dmg"
  name "ExSplit"
  desc "Split exercise PDFs into one exercise per sheet"
  homepage "https://github.com/jdevesablanco/ExSplit"

  depends_on macos: ">= :ventura"

  app "ExSplit.app"
  binary "#{appdir}/ExSplit.app/Contents/Resources/exsplit"

  zap trash: "~/Library/Application Support/ExSplit"
end
