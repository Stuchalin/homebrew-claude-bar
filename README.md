# homebrew-claude-bar

Homebrew tap for [ClaudeBar](https://github.com/Stuchalin/claude-bar), a macOS menu bar app
showing Claude subscription limits. Requires macOS 14 (Sonoma) or later.

## Install

```bash
brew install --cask stuchalin/claude-bar/claudebar
```

The app is installed to `/Applications/ClaudeBar.app`. The fully qualified install also tells
Homebrew to trust this cask ([Tap Trust](https://docs.brew.sh/Tap-Trust)).

## Upgrade

```bash
brew update
brew upgrade --cask claudebar
```

## First launch (Gatekeeper)

ClaudeBar is ad-hoc signed and not notarized, and Homebrew keeps the quarantine attribute.
If macOS blocks the first launch, open System Settings > Privacy & Security and click
**Open Anyway** for ClaudeBar ([Apple support](https://support.apple.com/102445)).

## Uninstall

```bash
brew uninstall --cask claudebar        # removes the app
brew uninstall --zap --cask claudebar  # also removes history and preferences
```

`--zap` removes `~/Library/Application Support/ClaudeBar` and the
`ru.sdfpro.ClaudeBar` preferences; the proxy secret in the Keychain is left untouched.
