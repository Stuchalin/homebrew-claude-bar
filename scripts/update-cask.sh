#!/usr/bin/env bash
# Regenerates Casks/claude-bar.rb from the latest ClaudeBar GitHub release.
#
# Requires gh (authenticated locally, or GH_TOKEN in CI) and curl. On every run
# it downloads the release zip and its .sha256 sidecar, verifies the zip against
# the sidecar, renders the expected Cask and rewrites Casks/claude-bar.rb only
# when the rendered content differs, so a drifted or manually broken Cask
# repairs itself on the next run. Any failure exits non-zero before the Cask is
# touched; the rewrite itself is an atomic rename within Casks/.
set -euo pipefail

SOURCE_REPO="Stuchalin/claude-bar"
TAG_RE='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cask="$root/Casks/claude-bar.rb"

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

workdir=$(mktemp -d)
staged=""
cleanup() {
  rm -rf "$workdir"
  if [[ -n "$staged" ]]; then
    rm -f "$staged"
  fi
}
trap cleanup EXIT

latest_tag=$(gh api "repos/$SOURCE_REPO/releases/latest" --jq .tag_name)
if ! [[ "$latest_tag" =~ $TAG_RE ]]; then
  echo "unexpected latest tag: $latest_tag" >&2
  exit 1
fi
version="${latest_tag#v}"
zip="ClaudeBar-$version.zip"
base="https://github.com/$SOURCE_REPO/releases/download/$latest_tag"

curl -fsSL -o "$workdir/$zip.sha256" "$base/$zip.sha256"
sidecar=$(cat "$workdir/$zip.sha256")
sidecar_re="^([0-9a-f]{64})  ${zip//./\\.}$"
if ! [[ "$sidecar" =~ $sidecar_re ]]; then
  echo "bad checksum sidecar for $zip: $sidecar" >&2
  exit 1
fi
expected="${BASH_REMATCH[1]}"

curl -fsSL -o "$workdir/$zip" "$base/$zip"
actual=$(digest "$workdir/$zip")
if [[ "$actual" != "$expected" ]]; then
  echo "checksum mismatch for $zip: sidecar $expected, zip $actual" >&2
  exit 1
fi

rendered="$workdir/claude-bar.rb"
cat > "$rendered" <<RUBY
cask "claude-bar" do
  version "$version"
  sha256 "$expected"

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
RUBY

if cmp -s "$rendered" "$cask"; then
  echo "cask is up to date ($version)"
  exit 0
fi

# Stage next to the Cask so the final mv is a same-filesystem atomic rename.
staged=$(mktemp "$root/Casks/.claude-bar.rb.XXXXXX")
cat "$rendered" > "$staged"
chmod 644 "$staged"
mv -f "$staged" "$cask"
staged=""
echo "regenerated Casks/claude-bar.rb from $latest_tag"
