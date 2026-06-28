#!/bin/bash
# install.sh - Install apply-wayland-flags
# Usage:
#   ./install.sh          # system-wide
#   ./install.sh --user   # per-user
#   ./install.sh --tui    # per-user with clickable TUI
#
# Works both from a local clone and via:
#   curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash

set -euo pipefail

REPO="https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main"

# ── Determine if we're running from a local copy or piped ────────
SCRIPT_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd 2>/dev/null || echo "")"

if [[ -f "$SCRIPT_DIR/apply-wayland-flags.sh" ]]; then
    fetch() { cp "$SCRIPT_DIR/$1" "$2"; }
    echo "  Using local files from $SCRIPT_DIR"
else
    fetch() {
        local url="$REPO/$1"
        curl -sSfL "$url" -o "$2"
    }
    echo "  Downloading from $REPO"
fi

# ── Parse args ───────────────────────────────────────────────────
INSTALL_TUI=false
case "${1:-}" in
    --user) INSTALL_DIR="$HOME/.local/bin" ; SYSTEMD_DIR="$HOME/.config/systemd/user" ; SUDO="" ;;
    --tui)  INSTALL_DIR="$HOME/.local/bin" ; SYSTEMD_DIR="$HOME/.config/systemd/user" ; SUDO="" ; INSTALL_TUI=true ;;
    *)      INSTALL_DIR="/usr/local/bin"   ; SYSTEMD_DIR="$HOME/.config/systemd/user" ; SUDO="sudo" ;;
esac

if $INSTALL_TUI; then
    echo "Installing with TUI (per-user)..."
elif [[ "$SUDO" == "" ]]; then
    echo "Installing for current user only..."
else
    echo "Installing system-wide (requires sudo)..."
fi

# ── Copy script ──────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
fetch "apply-wayland-flags.sh" "/tmp/apply-wayland-flags.sh"
$SUDO cp "/tmp/apply-wayland-flags.sh" "$INSTALL_DIR/apply-wayland-flags"
$SUDO chmod +x "$INSTALL_DIR/apply-wayland-flags"
rm -f "/tmp/apply-wayland-flags.sh"
echo "  + Script → $INSTALL_DIR/apply-wayland-flags"

SCRIPT_TARGET="$INSTALL_DIR/apply-wayland-flags"

# ── Systemd path unit ────────────────────────────────────────────
mkdir -p "$SYSTEMD_DIR"
fetch "hooks/apply-wayland-flags.service" "/tmp/apply-wayland-flags.service"
fetch "hooks/apply-wayland-flags.path" "/tmp/apply-wayland-flags.path"
sed -i "s|@SCRIPT@|$SCRIPT_TARGET|g" "/tmp/apply-wayland-flags.service"
$SUDO cp "/tmp/apply-wayland-flags.service" "$SYSTEMD_DIR/apply-wayland-flags.service"
$SUDO cp "/tmp/apply-wayland-flags.path" "$SYSTEMD_DIR/apply-wayland-flags.path"
echo "  + systemd: $SYSTEMD_DIR/apply-wayland-flags.{service,path}"

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now apply-wayland-flags.path 2>/dev/null || true
echo "  + systemd user path unit enabled and started."

# ── Distro-specific package manager hook ─────────────────────────
# (only installed in system-wide mode, requires write access to /etc)
if [[ "$SUDO" != "" ]]; then
    DISTRO=""
    if [[ -f /etc/os-release ]]; then
        DISTRO=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    fi

    case "$DISTRO" in
        arch|archarm|manjaro|endeavouros|cachyos|artix|arcolinux|garuda|rebornos)
            HOOK_DIR="/etc/pacman.d/hooks"
            echo "  Detected: Arch-based → installing pacman hook"
            $SUDO mkdir -p "$HOOK_DIR"
            fetch "hooks/pacman.hook" "/tmp/pacman.hook"
            sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "/tmp/pacman.hook"
            $SUDO cp "/tmp/pacman.hook" "$HOOK_DIR/apply-wayland-flags.hook"
            rm -f "/tmp/pacman.hook"
            echo "  + pacman hook: $HOOK_DIR/apply-wayland-flags.hook"
            ;;

        debian|ubuntu|linuxmint|pop|elementary|zorin|kali)
            HOOK_FILE="/etc/apt/apt.conf.d/99apply-wayland-flags"
            echo "  Detected: Debian-based → installing apt hook"
            fetch "hooks/apt.conf" "/tmp/apt.conf"
            sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "/tmp/apt.conf"
            $SUDO cp "/tmp/apt.conf" "$HOOK_FILE"
            rm -f "/tmp/apt.conf"
            echo "  + apt hook: $HOOK_FILE"
            ;;

        fedora|rhel|centos|rocky|alma)
            HOOK_DIR="/etc/dnf/plugins/post-transaction-actions.d"
            echo "  Detected: Fedora-based → installing dnf action"
            $SUDO mkdir -p "$HOOK_DIR"
            fetch "hooks/dnf.action" "/tmp/dnf.action"
            sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "/tmp/dnf.action"
            $SUDO cp "/tmp/dnf.action" "$HOOK_DIR/apply-wayland-flags.action"
            rm -f "/tmp/dnf.action"
            echo "  + dnf action: $HOOK_DIR/apply-wayland-flags.action"
            ;;

        opensuse*|suse)
            HOOK_DIR="/etc/zypp/plugins/commit"
            echo "  Detected: openSUSE → installing zypper hook"
            $SUDO mkdir -p "$HOOK_DIR"
            $SUDO tee "$HOOK_DIR/apply-wayland-flags" <<EOF
#!/bin/bash
su - $USER -c '$SCRIPT_TARGET' 2>/dev/null || true
EOF
            $SUDO chmod +x "$HOOK_DIR/apply-wayland-flags"
            echo "  + zypper hook: $HOOK_DIR/apply-wayland-flags"
            ;;

        *)
            echo "  Warning: Unrecognized distro '$DISTRO'."
            echo "  No package manager hook installed."
            echo "  The systemd path unit will still detect new apps via inotify."
            ;;
    esac
fi

# ── TUI (clickable app) ──────────────────────────────────────────
if $INSTALL_TUI; then
    echo "  Installing TUI (terminal interface)..."
    fetch "tui.sh" "/tmp/apply-wayland-flags-tui"
    $SUDO cp "/tmp/apply-wayland-flags-tui" "$INSTALL_DIR/apply-wayland-flags-tui"
    $SUDO chmod +x "$INSTALL_DIR/apply-wayland-flags-tui"
    rm -f "/tmp/apply-wayland-flags-tui"

    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/apply-wayland-flags-tui.desktop" << EOF
[Desktop Entry]
Name=Wayland Flags Manager
Comment=Apply fractional scaling fixes to Electron/Chromium apps
Exec=$INSTALL_DIR/apply-wayland-flags-tui
Terminal=true
Type=Application
Icon=preferences-system
Categories=Settings;Utility;
StartupNotify=false
EOF
    echo "  + TUI launcher → ~/.local/share/applications/apply-wayland-flags-tui.desktop"
    echo "  (Appears as 'Wayland Flags Manager' in your application menu)"
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications/" &>/dev/null || true
    fi
fi

# ── Cleanup ──────────────────────────────────────────────────────
rm -f /tmp/apply-wayland-flags.service /tmp/apply-wayland-flags.path

# ── First run ────────────────────────────────────────────────────
echo ""
echo "Running initial scan..."
$SUDO "$SCRIPT_TARGET" --full 2>/dev/null || "$SCRIPT_TARGET" --full 2>/dev/null || true

echo ""
echo "Installation complete!"
echo "Run '$SCRIPT_TARGET --full' manually anytime to rescan."
