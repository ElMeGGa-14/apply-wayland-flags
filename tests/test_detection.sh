#!/bin/bash

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_DIR/apply-wayland-flags.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

make_desktop() {
    local name=$1
    local command=$2
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n' \
        "$name" "$command" > "$tmp_dir/$name.desktop"
}

assert_detected() {
    if ! is_electron_app "$1"; then
        echo "Expected Electron/Chromium detection: $1" >&2
        exit 1
    fi
}

assert_not_detected() {
    if is_electron_app "$1"; then
        echo "Unexpected Electron/Chromium detection: $1" >&2
        exit 1
    fi
}

assert_contains() {
    local file=$1
    local expected=$2
    grep -qF -- "$expected" "$file" || {
        echo "Expected '$expected' in $file" >&2
        exit 1
    }
}

make_desktop chrome google-chrome-stable
assert_detected "$tmp_dir/chrome.desktop"

make_desktop heroic '/opt/Heroic/heroic %U'
assert_detected "$tmp_dir/heroic.desktop"

# Field codes embedded in arguments must not be split (for example Spotify's
# --uri=%u), while standalone field codes remain at the end of the command.
make_desktop spotify 'spotify --uri=%u'
add_flags_to_exec "$tmp_dir/spotify.desktop"
assert_contains "$tmp_dir/spotify.desktop" "Exec=spotify --uri=%u $FLAGS"

make_desktop chrome-pwa 'google-chrome-stable --profile-directory=Default --app-id=example %U'
add_flags_to_exec "$tmp_dir/chrome-pwa.desktop"
assert_contains "$tmp_dir/chrome-pwa.desktop" "Exec=google-chrome-stable --profile-directory=Default --app-id=example $FLAGS %U"

# Wrapper config files are created when absent, preserve user flags, and are
# idempotent. These flags also cover Chrome PWAs and direct binary launches.
OVERRIDE_DIR="$tmp_dir/overrides"
XDG_CONFIG_HOME="$tmp_dir/config"
mkdir -p "$OVERRIDE_DIR" "$XDG_CONFIG_HOME"
cp "$tmp_dir/chrome.desktop" "$OVERRIDE_DIR/google-chrome.desktop"
echo "$MARKER" >> "$OVERRIDE_DIR/google-chrome.desktop"
echo '--enable-features=ExampleUserFeature' > "$XDG_CONFIG_HOME/chrome-flags.conf"
handle_config_files
[[ "$CONFIG_COUNT" -eq 1 ]]
assert_contains "$XDG_CONFIG_HOME/chrome-flags.conf" '--enable-features=ExampleUserFeature'
assert_contains "$XDG_CONFIG_HOME/chrome-flags.conf" '--disable-features=WaylandFractionalScaleV1'
assert_contains "$XDG_CONFIG_HOME/chrome-flags.conf" '--ozone-platform-hint=wayland'
handle_config_files
[[ "$CONFIG_COUNT" -eq 0 ]]
[[ "$(grep -cF -- '--disable-features=WaylandFractionalScaleV1' "$XDG_CONFIG_HOME/chrome-flags.conf")" -eq 1 ]]

# Appending text preserves a valid executable ELF while reproducing strings
# that previously classified unrelated applications as Electron.
cp /bin/true "$tmp_dir/electronic-app"
printf 'Electronic\nSecure Electronic Transactions\nelectronvolt\n' >> "$tmp_dir/electronic-app"
chmod +x "$tmp_dir/electronic-app"
make_desktop unrelated "$tmp_dir/electronic-app"
assert_not_detected "$tmp_dir/unrelated.desktop"

for app in jamesdsp cachyos-hello gnome-calculator nwg-look; do
    binary=$(command -v "$app" 2>/dev/null || true)
    [[ -n "$binary" ]] || continue
    make_desktop "$app" "$binary"
    assert_not_detected "$tmp_dir/$app.desktop"
done

echo "Detection tests passed."
