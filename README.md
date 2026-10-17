# homebrew-claude-bar

Homebrew tap for [ClaudeBar](https://github.com/Stuchalin/claude-bar), a macOS menu bar app
showing Claude subscription limits. Requires macOS 14 (Sonoma) or later.

## Install

```bash
brew install --cask stuchalin/claude-bar/claude-bar
```

The app is installed to `/Applications/ClaudeBar.app`. The fully qualified install also tells
Homebrew to trust this cask ([Tap Trust](https://docs.brew.sh/Tap-Trust)).

Always use the fully qualified name `stuchalin/claude-bar/claude-bar`. The cask token is
`claude-bar`, not `claudebar`: the official Homebrew cask `claudebar` is a different app, and a
bare `claudebar` resolves to it.

## Upgrade

```bash
brew update
brew upgrade --cask stuchalin/claude-bar/claude-bar
```

## Migrating from the old `claudebar` token

Earlier versions of this tap used the token `claudebar`. Homebrew does not migrate it
automatically. To move to `claude-bar`:

1. Quit ClaudeBar.
2. Remove the old cask without `--zap`, so history and preferences stay:

   ```bash
   brew uninstall --cask claudebar
   ```

3. Install the new token:

   ```bash
   brew install --cask stuchalin/claude-bar/claude-bar
   ```

## First launch (Gatekeeper)

ClaudeBar is ad-hoc signed and not notarized, and Homebrew keeps the quarantine attribute.
If macOS blocks the first launch, open System Settings > Privacy & Security and click
**Open Anyway** for ClaudeBar ([Apple support](https://support.apple.com/102445)).

## Uninstall

```bash
brew uninstall --cask stuchalin/claude-bar/claude-bar        # removes the app
brew uninstall --zap --cask stuchalin/claude-bar/claude-bar  # also removes history and preferences
```

`--zap` removes `~/Library/Application Support/ClaudeBar` and the
`ru.sdfpro.ClaudeBar` preferences; the proxy secret in the Keychain is left untouched.

## Automatic updates

`.github/workflows/update-cask.yml` runs `scripts/update-cask.sh` every hour and on demand. The
script reads the latest [ClaudeBar release](https://github.com/Stuchalin/claude-bar/releases),
downloads `ClaudeBar-X.Y.Z.zip` and its `.sha256` sidecar, verifies the zip against the sidecar
and rewrites `Casks/claude-bar.rb` only when the rendered Cask differs. The workflow then commits
the change as `github-actions[bot]`. Any error (unexpected tag, missing asset, checksum mismatch,
network failure) fails the run and leaves the Cask as it was.

Run it manually from the Actions tab (**Update cask** > **Run workflow**) or with:

```bash
gh workflow run update-cask.yml -R Stuchalin/homebrew-claude-bar
```

GitHub disables scheduled workflows in a public repository after 60 days without repository
activity. To turn the schedule back on, open Actions > **Update cask** and click
**Enable workflow**, or run:

```bash
gh workflow enable update-cask.yml -R Stuchalin/homebrew-claude-bar
```

To run the script or its fixture tests locally (the tests stub `gh` and `curl` and touch neither
the network nor the real Cask):

```bash
scripts/update-cask.sh
scripts/test-update-cask.sh
```
