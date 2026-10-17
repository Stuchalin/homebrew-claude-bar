cask "claudebar" do
  version "0.1.0"
  sha256 "3166de4bb7bec03277a35e810e156af370b3507087879069bc2fcf4760bc5b92"

  url "https://github.com/Stuchalin/claude-bar/releases/download/v#{version}/ClaudeBar-#{version}.zip"
  name "ClaudeBar"
  desc "Menu bar app showing Claude subscription limits"
  homepage "https://github.com/Stuchalin/claude-bar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "ClaudeBar.app"

  uninstall quit: "ru.sdfpro.ClaudeBar"

  zap trash: [
    "~/Library/Application Support/ClaudeBar",
    "~/Library/Preferences/ru.sdfpro.ClaudeBar.plist",
  ]

  caveats <<~EOS
    ClaudeBar is ad-hoc signed and not notarized. If macOS blocks the first
    launch, open System Settings > Privacy & Security and click "Open Anyway"
    for ClaudeBar: https://support.apple.com/102445
  EOS
end
