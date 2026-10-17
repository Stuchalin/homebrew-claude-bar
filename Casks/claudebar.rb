cask "claudebar" do
  version "0.1.1"
  sha256 "242401cc5a1d5653aa7622b1c2e557548e15425454359b05d374d2e4d0546895"

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
