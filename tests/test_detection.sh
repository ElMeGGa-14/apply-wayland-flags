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

make_desktop chrome google-chrome-stable
assert_detected "$tmp_dir/chrome.desktop"

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
