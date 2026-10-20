class Splitexercises < Formula
  desc "Split exercise PDFs into one exercise per sheet (macOS menu bar app + CLI)"
  homepage "https://github.com/jdevesablanco/SplitExercises"
  url "https://github.com/jdevesablanco/SplitExercises/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "c310e60bb28b87455fe41395d12d74d6cbcff1cae40b77a734c170e0a2a75cb4"
  license "MIT"
  head "https://github.com/jdevesablanco/SplitExercises.git", branch: "main"

  depends_on :macos
  depends_on macos: :ventura

  def install
    # Se compila en tu Mac con las Command Line Tools: no hay descarga binaria, así que Gatekeeper no pone pegas.
    ENV["SPLITEXERCISES_NO_SANDBOX"] = "1"
    ENV["VERSION"] = version.to_s
    system "Scripts/build-app.sh"
    prefix.install "build/SplitExercises.app"
    bin.install_symlink prefix/"SplitExercises.app/Contents/Resources/splitexercises"
  end

  def caveats
    <<~EOS
      SplitExercises.app has been built locally. To copy it to /Applications and open it (first-run setup):
        splitexercises install
      Run `splitexercises install` again after each `brew upgrade splitexercises`.
    EOS
  end

  test do
    system bin/"splitexercises", "selftest"
  end
end
