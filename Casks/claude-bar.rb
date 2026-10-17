cask "claude-bar" do
  version "0.1.2"
  sha256 "eed51c58bf8fd9b1cf31c7dfd77187cab40a81018dabe5e5c98e23efcce563bb"

  url "https://github.com/Stuchalin/claude-bar/releases/download/v#{version}/ClaudeBar-#{version}.zip"
  name "ClaudeBar"
  desc "Menu bar app showing Claude subscription limits"
  homepage "https://github.com/Stuchalin/claude-bar"

  livecheck do
    url :url
    strategy :github_latest
  end

  conflicts_with cask: "claudebar"
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
