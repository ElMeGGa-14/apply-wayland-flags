#!/bin/bash
# apply-wayland-flags.sh - Detect and fix fractional scaling issues
# in Electron/Chromium apps on Wayland
#
# Scans installed desktop files for Electron/Chromium apps and adds
# --disable-features=WaylandFractionalScaleV1 --ozone-platform-hint=wayland
# to their Exec lines via local overrides (~/.local/share/applications/).
#
# Also handles Flatpak apps via flatpak override --user --env.
#
# Usage:
#   apply-wayland-flags.sh          # incremental (new apps only)
#   apply-wayland-flags.sh --full   # full rescan (re-detect everything)

set -uo pipefail

FLAGS="--disable-features=WaylandFractionalScaleV1 --ozone-platform-hint=wayland"
OVERRIDE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$OVERRIDE_DIR"

# ── Known Electron/Chromium binary names ──────────────────────────
KNOWN_BINARIES=(
    google-chrome google-chrome-stable google-chrome-beta google-chrome-unstable
    chromium chromium-browser chromium-bsu
    brave brave-browser
    microsoft-edge microsoft-edge-dev microsoft-edge-beta
    vivaldi vivaldi-bin vivaldi-snapshot
    opera opera-beta opera-developer
    yandex-browser yandex-browser-beta
    arc-browser arc
    ungoogled-chromium ungoogled-chromium-bin
    iridium iridium-browser
    epic epic-browser
    slimjet slimjet-browser
    naver-whale whale whale-browser
    cent-browser cent
    code code-oss codium
    opencode-desktop opencode
    cursor
    antigravity antigravity-cli
    microsoft-teams teams teams-for-linux mattermost-desktop
    mongodb-compass figma-linux github-desktop
    gitkraken joplin typora marktext
    ferdium ferdi vesktop armcord
    threema session-desktop standard-notes
    electron
)

KNOWN_DESKTOP_PREFIXES=(
    discord slack whatsapp teams signal postman obsidian notion figma
    todoist spotify zoom insomnia anydesk teamviewer
    logseq zulip element keybase
    github-desktop gitkraken
    marktext typora joplin
    ferdium ferdi vesktop
    threema standard-notes
    mongodb-compass
    yandex-browser iridium-browser
    epic-browser slimjet
    naver-whale cent-browser
    arc-browser ungoogled-chromium
)

# ── Known Electron/Chromium Flatpak IDs ──────────────────────────
KNOWN_FLATPAK_IDS=(
    com.google.Chrome
    org.chromium.Chromium
    com.brave.Browser
    com.microsoft.Edge
    com.vivaldi.Vivaldi
    com.opera.Opera
    com.discordapp.Discord
    com.slack.Slack
    com.signal.Signal
    com.visualstudio.code
    com.visualstudio.code-oss
    md.obsidian.Obsidian
    rest.insomnia.Insomnia
    io.github.zen_browser.zen
    com.postman.Postman
)

# ── Detection ──────────────────────────────────────────────────────
is_electron_app() {
    local desktop_file="$1"
    local basename exec_line binary full_path

    basename=$(basename "$desktop_file" .desktop)
    exec_line=$(grep -m1 '^Exec=' "$desktop_file" 2>/dev/null || true)
    [[ -z "$exec_line" ]] && return 1

    binary=$(echo "$exec_line" | sed 's/^Exec=//' | awk '{print $1}' | xargs basename 2>/dev/null || true)
    full_path=$(echo "$exec_line" | sed 's/^Exec=//' | awk '{print $1}' 2>/dev/null || true)

    for b in "${KNOWN_BINARIES[@]}"; do
        [[ "$binary" == "$b" ]] && return 0
    done

    for prefix in "${KNOWN_DESKTOP_PREFIXES[@]}"; do
        [[ "$basename" == "$prefix" ]] && return 0
    done

    for b in "${KNOWN_BINARIES[@]}"; do
        [[ "$basename" == "$b" ]] && return 0
    done

    if echo "$full_path" | grep -qiE "(electron|chromium|chrome)"; then
        return 0
    fi

    if [[ ! "$full_path" == */* ]] && type -P "$full_path" &>/dev/null; then
        full_path=$(type -P "$full_path")
    fi

    if [[ -L "$full_path" ]]; then
        full_path=$(readlink -f "$full_path")
    fi

    if [[ -x "$full_path" ]] && file "$full_path" 2>/dev/null | grep -qi "ELF"; then
        if ldd "$full_path" 2>/dev/null | grep -qiE "(libelectron|libcef|libchrome)"; then
            return 0
        fi
        if strings "$full_path" 2>/dev/null | grep -qiE "(electron|chromium)"; then
            return 0
        fi
    fi

    return 1
}

# ── Desktop file patching ─────────────────────────────────────────
add_flags_to_exec() {
    local file="$1"
    local tmp=$(mktemp)

    while IFS= read -r line; do
        if [[ "$line" == Exec=* ]]; then
            if [[ "$line" != *"$FLAGS"* ]]; then
                local new_line
                if echo "$line" | grep -q '%[UuFfDdNnVvMm]'; then
                    new_line=$(echo "$line" | sed "s|^Exec=\([^ ]*\) \(.*%[^ ]*\)|Exec=\1 $FLAGS \2|")
                else
                    new_line="Exec=$(echo "$line" | sed 's/^Exec=//') $FLAGS"
                fi
                echo "$new_line" >> "$tmp"
            else
                echo "$line" >> "$tmp"
            fi
        else
            echo "$line" >> "$tmp"
        fi
    done < "$file"

    mv "$tmp" "$file"
    chmod 644 "$file"
}

# ── Flatpak handling ──────────────────────────────────────────────
handle_flatpak() {
    command -v flatpak &>/dev/null || return 0

    local flatpak_applied=0
    local flatpak_list

    flatpak_list=$(flatpak list --app --columns=application 2>/dev/null) || return 0

    for id in "${KNOWN_FLATPAK_IDS[@]}"; do
        if echo "$flatpak_list" | grep -qiF "$id"; then
            if echo "$id" | grep -qiE "(chrome|chromium|brave|edge|vivaldi|opera|yandex|iridium|slimjet|whale|cent|epic)"; then
                flatpak override --user --env=CHROME_FLAGS="$FLAGS" "$id" &>/dev/null
            fi
            flatpak override --user --env=ELECTRON_EXTRA_LAUNCH_ARGS="$FLAGS" "$id" &>/dev/null
            echo "  + flatpak: $id"
            ((flatpak_applied++))
        fi
    done

    flatpak override --user --env=ELECTRON_EXTRA_LAUNCH_ARGS="$FLAGS" &>/dev/null
    flatpak override --user --env=CHROME_FLAGS="$FLAGS" &>/dev/null
    echo "  + flatpak: global overrides set (ELECTRON_EXTRA_LAUNCH_ARGS + CHROME_FLAGS)"

    FLATPAK_RESULT=$((flatpak_applied + 1))
}

FLATPAK_DESKTOP_DIRS=(
    /var/lib/flatpak/exports/share/applications
    "$HOME/.local/share/flatpak/exports/share/applications"
)

# ── Main ──────────────────────────────────────────────────────────
mode="incremental"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full|-f) mode="full" ;;
        *) echo "Usage: $0 [--full|-f]" >&2; exit 1 ;;
    esac
    shift
done

if [[ "$mode" == "full" ]]; then
    for f in "$OVERRIDE_DIR"/*.desktop; do
        [[ -f "$f" ]] || continue
        case "$(basename "$f")" in
            apply-wayland-flags-tui.desktop) continue ;;
        esac
        rm -f "$f"
    done
    echo "Full rescan: cleared existing overrides."
fi

applied=0
flatpak_applied=0

for dir in /usr/share/applications "${FLATPAK_DESKTOP_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for desktop_file in "$dir"/*.desktop; do
    [[ -f "$desktop_file" ]] || continue
    name=$(basename "$desktop_file")
    override="$OVERRIDE_DIR/$name"

    [[ -f "$override" ]] && continue

    if is_electron_app "$desktop_file"; then
        cp "$desktop_file" "$override"
        add_flags_to_exec "$override"
        echo "  + $name"
        ((applied++))
    fi
    done
done

FLATPAK_RESULT=0
handle_flatpak
flatpak_count=$FLATPAK_RESULT

if [[ "$applied" -eq 0 ]] && [[ "$flatpak_count" -eq 0 ]]; then
    echo "No Electron/Chromium apps found."
else
    echo "Applied: $applied desktop file(s), $flatpak_count flatpak override(s)."
fi
