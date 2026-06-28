# apply-wayland-flags

Fix blurry text, flickering, and UI glitches in Electron/Chromium apps on Wayland with fractional scaling.

Automatically adds `--disable-features=WaylandFractionalScaleV1 --ozone-platform-hint=wayland` to all installed Electron/Chromium apps — **including newly installed ones**.

## Quick Install

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash
```

Or for a per-user install (no sudo):

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash -s -- --user
```

## What it does

| Mechanism | Coverage |
|---|---|
| **Desktop file overrides** (`~/.local/share/applications/`) | Native .deb/.rpm/.pkg.tar.zst apps |
| **Systemd path unit** (inotify) | Catches new apps at runtime, 0 CPU when idle |
| **Package manager hook** | Runs after every `apt install` / `pacman -Syu` / `dnf install` |
| **Flatpak global overrides** | `ELECTRON_EXTRA_LAUNCH_ARGS` + `CHROME_FLAGS` for all Flatpaks |

### Supported distros

- **Arch, Manjaro, EndeavourOS, CachyOS** → pacman hook
- **Debian, Ubuntu, Mint, Pop!_OS** → apt hook
- **Fedora, RHEL, CentOS** → dnf action
- **openSUSE** → zypper hook
- **Any distro with systemd** → path unit (fallback)

## Manual usage

```bash
# Full rescan (re-detect everything)
apply-wayland-flags --full

# Incremental (new apps only)
apply-wayland-flags
```

## Supported apps

<details>
<summary>Click to expand</summary>

**Browsers:** Google Chrome, Chromium, Brave, Edge, Vivaldi, Opera, Yandex Browser, Arc, Ungoogled Chromium, Iridium, Epic, Slimjet, Naver Whale, Cent Browser

**Editors/IDEs:** VS Code, VS Code OSS, VSCodium, Cursor, Antigravity, OpenCode

**Communication:** Discord, Slack, Teams, Signal, WhatsApp, Mattermost, Zulip, Element, Keybase, Threema, Session

**Productivity:** Obsidian, Notion, Figma, Todoist, Postman, Insomnia, Standard Notes, Logseq

**Other:** Spotify, Zoom, AnyDesk, TeamViewer, GitHub Desktop, GitKraken, Joplin, Typora, MarkText, Ferdium, Ferdi, Vesktop, ArmCord, mongodb-compass

</details>

## How it works

1. Scans `.desktop` files in `/usr/share/applications/` and Flatpak export directories
2. Detects Electron/Chromium apps by binary name, desktop file name, and binary inspection (symlink-aware, `strings` fallback)
3. Copies matching `.desktop` files to `~/.local/share/applications/` with flags added to `Exec=` lines
4. Sets Flatpak global overrides via `flatpak override --user --env=...`

The systemd path unit uses `inotify` — **zero resource usage** when idle.

## Uninstall

```bash
sudo rm -f /usr/local/bin/apply-wayland-flags
rm -f ~/.local/share/applications/*chromium* ~/.local/share/applications/*chrome* ...
rm -f ~/.config/systemd/user/apply-wayland-flags.{service,path}
```

## License

MIT
