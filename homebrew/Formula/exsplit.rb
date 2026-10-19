class Exsplit < Formula
  desc "Split exercise PDFs into one exercise per sheet (macOS menu bar app + CLI)"
  homepage "https://github.com/jdevesablanco/ExSplit"
  url "https://github.com/jdevesablanco/ExSplit/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256"
  license "MIT"
  head "https://github.com/jdevesablanco/ExSplit.git", branch: "main"

  depends_on :macos
  depends_on macos: :ventura

  def install
    # Se compila en tu Mac con las Command Line Tools: no hay descarga binaria, así que Gatekeeper no pone pegas.
    ENV["EXSPLIT_NO_SANDBOX"] = "1"
    ENV["VERSION"] = version.to_s
    system "Scripts/build-app.sh"
    prefix.install "build/ExSplit.app"
    bin.install_symlink prefix/"ExSplit.app/Contents/Resources/exsplit"
  end

  def caveats
    <<~EOS
      ExSplit.app has been built locally. To copy it to ~/Applications and open it (first-run setup):
        exsplit install
      Run `exsplit install` again after each `brew upgrade exsplit`.
    EOS
  end

  test do
    system bin/"exsplit", "selftest"
  end
end
