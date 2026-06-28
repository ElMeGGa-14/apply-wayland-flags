#!/bin/bash
# install.sh - Install apply-wayland-flags system-wide
# Usage: ./install.sh [--user]

set -euo pipefail

SCRIPT_SRC="$(dirname "$0")/apply-wayland-flags.sh"
SERVICE_SRC="$(dirname "$0")/hooks/apply-wayland-flags.service"
PATH_SRC="$(dirname "$0")/hooks/apply-wayland-flags.path"

if [[ "${1:-}" == "--user" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    SUDO=""
    echo "Installing for current user only..."
else
    INSTALL_DIR="/usr/local/bin"
    SYSTEMD_DIR="/etc/systemd/user"
    SUDO="sudo"
    echo "Installing system-wide (requires sudo)..."
fi

# ── Copy script ──────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
$SUDO cp "$SCRIPT_SRC" "$INSTALL_DIR/apply-wayland-flags"
$SUDO chmod +x "$INSTALL_DIR/apply-wayland-flags"
echo "  + Script → $INSTALL_DIR/apply-wayland-flags"

# ── Systemd path unit ────────────────────────────────────────────
mkdir -p "$SYSTEMD_DIR"
$SUDO cp "$SERVICE_SRC" "$SYSTEMD_DIR/apply-wayland-flags.service"
$SUDO cp "$PATH_SRC" "$SYSTEMD_DIR/apply-wayland-flags.path"

SCRIPT_TARGET="$INSTALL_DIR/apply-wayland-flags"
$SUDO sed -i "s|@SCRIPT@|$SCRIPT_TARGET|g" "$SYSTEMD_DIR/apply-wayland-flags.service"

echo "  + systemd: $SYSTEMD_DIR/apply-wayland-flags.{service,path}"

if [[ "$SUDO" == "" ]]; then
    systemctl --user daemon-reload
    systemctl --user enable --now apply-wayland-flags.path
    echo "  + systemd user path unit enabled and started."
else
    sudo systemctl --user daemon-reload 2>/dev/null || true
    sudo systemctl --user enable --now apply-wayland-flags.path 2>/dev/null || true
    echo "  + systemd user path unit enabled. (Run 'systemctl --user enable --now apply-wayland-flags.path' if needed)"
fi

# ── Distro-specific package manager hook ─────────────────────────
DISTRO=""
if [[ -f /etc/os-release ]]; then
    DISTRO=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

case "$DISTRO" in
    arch|archarm|manjaro|endeavouros|cachyos|artix|arcolinux|garuda|rebornos)
        HOOK_DIR="/etc/pacman.d/hooks"
        echo "  Detected: Arch-based → installing pacman hook"
        $SUDO mkdir -p "$HOOK_DIR"
        $SUDO cp "$(dirname "$0")/hooks/pacman.hook" "$HOOK_DIR/apply-wayland-flags.hook"
        $SUDO sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "$HOOK_DIR/apply-wayland-flags.hook"
        echo "  + pacman hook: $HOOK_DIR/apply-wayland-flags.hook"
        ;;

    debian|ubuntu|linuxmint|pop|elementary|zorin|kali)
        HOOK_FILE="/etc/apt/apt.conf.d/99apply-wayland-flags"
        echo "  Detected: Debian-based → installing apt hook"
        $SUDO cp "$(dirname "$0")/hooks/apt.conf" "$HOOK_FILE"
        $SUDO sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "$HOOK_FILE"
        echo "  + apt hook: $HOOK_FILE"
        ;;

    fedora|rhel|centos|rocky|alma)
        HOOK_DIR="/etc/dnf/plugins/post-transaction-actions.d"
        echo "  Detected: Fedora-based → installing dnf action"
        $SUDO mkdir -p "$HOOK_DIR"
        $SUDO cp "$(dirname "$0")/hooks/dnf.action" "$HOOK_DIR/apply-wayland-flags.action"
        $SUDO sed -i "s|@USER@|$USER|g; s|@SCRIPT@|$SCRIPT_TARGET|g" "$HOOK_DIR/apply-wayland-flags.action"
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

# ── First run ────────────────────────────────────────────────────
echo ""
echo "Running initial scan..."
$SUDO "$SCRIPT_TARGET" --full 2>/dev/null || "$SCRIPT_TARGET" --full 2>/dev/null || true

echo ""
echo "Installation complete!"
echo "Run '$SCRIPT_TARGET --full' manually anytime to rescan."
