#!/usr/bin/env bash
# Fixture tests for scripts/update-cask.sh. Runs the updater against a copy of
# the tap in a temporary directory with stub gh and curl on PATH, so nothing
# touches the network or the real Cask.
#
# Optional: TEST_NETWORK=1 also runs the updater with the real gh and curl
# against the published release on a copy of the committed Cask and expects a
# no-op (the latest release must be the one the Cask already pins).
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base_url="https://github.com/Stuchalin/claude-bar/releases/download"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Stubs. gh prints $STUB_TAG (or fails with STUB_GH_FAIL=1); curl serves files
# from $STUB_RELEASES/<tag>/<asset>, exits 22 (HTTP error) for a missing asset
# and 6 (network) with STUB_CURL_FAIL=1.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
if [[ "${STUB_GH_FAIL:-}" == 1 ]]; then
  echo "error connecting to api.github.com" >&2
  exit 1
fi
if [[ "$*" != "api repos/Stuchalin/claude-bar/releases/latest --jq .tag_name" ]]; then
  echo "stub gh: unexpected arguments: $*" >&2
  exit 2
fi
printf '%s\n' "$STUB_TAG"
STUB
cat > "$tmp/bin/curl" <<STUB
#!/usr/bin/env bash
if [[ "\${STUB_CURL_FAIL:-}" == 1 ]]; then
  echo "curl: (6) Could not resolve host: github.com" >&2
  exit 6
fi
out="" url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
prefix="$base_url/"
if [[ "\$url" != "\$prefix"* || -z "\$out" ]]; then
  echo "stub curl: unexpected request \$url -> \$out" >&2
  exit 2
fi
src="\$STUB_RELEASES/\${url#"\$prefix"}"
if [[ ! -f "\$src" ]]; then
  echo "curl: (22) The requested URL returned error: 404" >&2
  exit 22
fi
cp "\$src" "\$out"
STUB
chmod +x "$tmp/bin/gh" "$tmp/bin/curl"

digest() { shasum -a 256 "$1" | cut -d' ' -f1; }

# Release fixtures. make_release TAG [SIDECAR_HASH] writes a fake zip and a
# sidecar that matches it unless a hash is given.
releases="$tmp/releases"
make_release() {
  local tag="$1" version="${1#v}" dir sum
  dir="$releases/$tag"
  mkdir -p "$dir"
  printf 'fake ClaudeBar %s\n' "$version" > "$dir/ClaudeBar-$version.zip"
  sum="${2:-$(digest "$dir/ClaudeBar-$version.zip")}"
  printf '%s  ClaudeBar-%s.zip\n' "$sum" "$version" > "$dir/ClaudeBar-$version.zip.sha256"
}

tap="$tmp/tap"
reset_tap() {
  rm -rf "$tap"
  mkdir -p "$tap/scripts" "$tap/Casks"
  cp "$repo/scripts/update-cask.sh" "$tap/scripts/"
  cp "$repo/Casks/claude-bar.rb" "$tap/Casks/"
}

pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
not_ok() { fail=$((fail + 1)); echo "FAIL $1" >&2; }

run_updater() {
  PATH="$tmp/bin:$PATH" STUB_RELEASES="$releases" "$tap/scripts/update-cask.sh" > "$tmp/out" 2>&1
}

# Expects a non-zero exit with MESSAGE in the output, a byte-identical Cask and
# no staged leftovers.
expect_failure() {
  local name="$1" message="$2" before
  reset_tap
  before=$(digest "$tap/Casks/claude-bar.rb")
  if run_updater; then
    not_ok "$name: expected non-zero exit"
  elif ! grep -qF -- "$message" "$tmp/out"; then
    not_ok "$name: output lacks '$message': $(cat "$tmp/out")"
  elif [[ "$(digest "$tap/Casks/claude-bar.rb")" != "$before" ]]; then
    not_ok "$name: cask changed"
  elif [[ -n "$(find "$tap/Casks" -name '.claude-bar.rb.*')" ]]; then
    not_ok "$name: staged file left behind"
  else
    ok "$name"
  fi
}

# --- new release rewrites only version and sha256 --------------------------
make_release v0.2.0
reset_tap
new_sum=$(digest "$releases/v0.2.0/ClaudeBar-0.2.0.zip")
sed -e 's/^  version "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"$/  version "0.2.0"/' \
    -e "s/^  sha256 \"[0-9a-f]\{64\}\"$/  sha256 \"$new_sum\"/" \
    "$repo/Casks/claude-bar.rb" > "$tmp/expected.rb"
if STUB_TAG=v0.2.0 run_updater && cmp -s "$tap/Casks/claude-bar.rb" "$tmp/expected.rb" \
    && grep -q 'regenerated' "$tmp/out"; then
  ok "new release rewrites version and sha256 only"
else
  not_ok "new release rewrite"; diff "$tmp/expected.rb" "$tap/Casks/claude-bar.rb" >&2 || true
fi

# --- rendered Cask keeps the renamed token and the conflict with "claudebar" --
if grep -qx 'cask "claude-bar" do' "$tap/Casks/claude-bar.rb" \
    && grep -qx '  conflicts_with cask: "claudebar"' "$tap/Casks/claude-bar.rb"; then
  ok "rendered cask has token claude-bar and conflicts_with claudebar"
else
  not_ok "rendered cask token or conflicts_with line"
fi

# --- repeat run is a no-op ---------------------------------------------------
before=$(digest "$tap/Casks/claude-bar.rb")
touch -t 200001010000 "$tap/Casks/claude-bar.rb"
if STUB_TAG=v0.2.0 run_updater && grep -q 'up to date' "$tmp/out" \
    && [[ "$(digest "$tap/Casks/claude-bar.rb")" == "$before" ]] \
    && [[ -z "$(find "$tap/Casks/claude-bar.rb" -newermt 2000-01-02)" ]]; then
  ok "repeat run is a no-op"
else
  not_ok "repeat run"
fi

# --- drifted Cask is repaired --------------------------------------------------
echo "# stray" >> "$tap/Casks/claude-bar.rb"
if STUB_TAG=v0.2.0 run_updater && cmp -s "$tap/Casks/claude-bar.rb" "$tmp/expected.rb"; then
  ok "drifted cask is re-rendered"
else
  not_ok "drifted cask repair"
fi

# --- malformed tags --------------------------------------------------------------
for tag in 0.2.0 v0.2 v0.2.0.1 v01.2.0 v0.02.0 v0.2.0-beta "v0.2.0 " V0.2.0 "" "v0.2.0
v0.3.0"; do
  STUB_TAG="$tag" expect_failure "malformed tag '${tag//$'\n'/\\n}'" "unexpected latest tag"
done

# --- digest mismatch and malformed sidecars ----------------------------------------
make_release v0.3.0 "$(printf '0%.0s' {1..64})"
STUB_TAG=v0.3.0 expect_failure "digest mismatch" "checksum mismatch"

make_release v0.4.0
printf 'ABCDEF  ClaudeBar-0.4.0.zip\n' > "$releases/v0.4.0/ClaudeBar-0.4.0.zip.sha256"
STUB_TAG=v0.4.0 expect_failure "sidecar with a malformed hash" "bad checksum sidecar"

make_release v0.5.0
printf '%s  ClaudeBar-0.4.0.zip\n' "$(digest "$releases/v0.5.0/ClaudeBar-0.5.0.zip")" \
  > "$releases/v0.5.0/ClaudeBar-0.5.0.zip.sha256"
STUB_TAG=v0.5.0 expect_failure "sidecar naming another file" "bad checksum sidecar"

# Dots in the file name are literal, not regex wildcards.
make_release v0.8.0
printf '%s  ClaudeBar-0x8x0.zip\n' "$(digest "$releases/v0.8.0/ClaudeBar-0.8.0.zip")" \
  > "$releases/v0.8.0/ClaudeBar-0.8.0.zip.sha256"
STUB_TAG=v0.8.0 expect_failure "sidecar name with wildcard dots" "bad checksum sidecar"

# Exactly one line: trailing content is rejected.
make_release v0.9.0
printf 'extra\n' >> "$releases/v0.9.0/ClaudeBar-0.9.0.zip.sha256"
STUB_TAG=v0.9.0 expect_failure "sidecar with extra lines" "bad checksum sidecar"

# --- missing assets ------------------------------------------------------------------
make_release v0.6.0
rm "$releases/v0.6.0/ClaudeBar-0.6.0.zip"
STUB_TAG=v0.6.0 expect_failure "missing zip" "(22)"

make_release v0.7.0
rm "$releases/v0.7.0/ClaudeBar-0.7.0.zip.sha256"
STUB_TAG=v0.7.0 expect_failure "missing sidecar" "(22)"

# --- network failures -------------------------------------------------------------------
STUB_TAG=v0.2.0 STUB_GH_FAIL=1 expect_failure "gh network failure" "error connecting"
STUB_TAG=v0.2.0 STUB_CURL_FAIL=1 expect_failure "curl network failure" "(6)"

# --- optional: real release, committed Cask must be a no-op ------------------------------
if [[ "${TEST_NETWORK:-}" == 1 ]]; then
  reset_tap
  before=$(digest "$tap/Casks/claude-bar.rb")
  if "$tap/scripts/update-cask.sh" > "$tmp/out" 2>&1 && grep -q 'up to date' "$tmp/out" \
      && [[ "$(digest "$tap/Casks/claude-bar.rb")" == "$before" ]]; then
    ok "network: committed cask matches the latest release"
  else
    not_ok "network: $(cat "$tmp/out")"
  fi
fi

echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
