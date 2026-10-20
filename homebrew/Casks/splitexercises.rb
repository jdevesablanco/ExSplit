cask "splitexercises" do
  version "1.0.1"
  sha256 "31b8e265e3688315058b7f0bc75673503de8047b6ff573ca3f69e147d4b584b3"

  url "https://github.com/jdevesablanco/SplitExercises/releases/download/v#{version}/SplitExercises-#{version}.dmg"
  name "SplitExercises"
  desc "Split exercise PDFs into one exercise per sheet"
  homepage "https://github.com/jdevesablanco/SplitExercises"

  depends_on macos: :ventura

  app "SplitExercises.app"
  binary "#{appdir}/SplitExercises.app/Contents/Resources/splitexercises"

  # La app no está notarizada (no hay cuenta de Apple Developer de pago): sin esto macOS la bloquearía al abrirla.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/SplitExercises.app"]
  end

  uninstall quit: "io.github.jdevesablanco.SplitExercises"
  zap trash: [
    "~/Library/Application Support/SplitExercises",
    "~/Library/Application Support/RightYourClick/actions/io.github.jdevesablanco.SplitExercises.split.json",
    "~/Library/Services/SplitExercises.workflow",
    "~/Library/Preferences/io.github.jdevesablanco.SplitExercises.plist",
  ]
end
