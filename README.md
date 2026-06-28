# apply-wayland-flags

Automatically applies `--disable-features=WaylandFractionalScaleV1 --ozone-platform-hint=wayland` to installed Electron/Chromium apps — including newly installed ones — to fix blurry text, flickering, and UI glitches caused by fractional scaling on Wayland.

## Quick install

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash
```

User-only install (no sudo):

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash -s -- --user
```

Install with TUI (clickable app in your application menu, no sudo):

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash -s -- --tui
```

After install, run once or wait for the next login:

```bash
apply-wayland-flags --full
```

## Why

Electron and Chromium applications use the `wp_fractional_scale_v1` Wayland protocol by default, which causes rendering issues at non-integer scale factors:

- **Above 100%** (125%, 150%, 200%...): blurry text, flickering, disproportionate UI elements
- **Below 100%** (75%, 50%...): oversized transparent margins, broken window rendering, elements failing to repaint

Disabling this feature and forcing the Wayland ozone platform hint resolves these issues across all fractional scales.

## How it detects apps

The script identifies Electron/Chromium applications through four methods:

1. **Known binary names** — matches the `Exec=` binary from `.desktop` files against a maintained list
2. **Desktop file names** — matches the `.desktop` filename against the same list
3. **Path inspection** — catches any binary whose path contains "electron", "chromium", or "chrome"
4. **Binary analysis** — resolves symlinks, then inspects ELF binaries via `ldd` and `strings` for Electron/Chromium references (catches bundled apps like Cursor, Antigravity, etc.)

## What gets installed

| Path | Purpose |
|---|---|
| `/usr/local/bin/apply-wayland-flags` (o `~/.local/bin/`) | The detection and patching script |
| `~/.config/systemd/user/apply-wayland-flags.{path,service}` | Systemd user path unit — monitors `/usr/share/applications/` via inotify, 0 CPU when idle |
| `/etc/pacman.d/hooks/apply-wayland-flags.hook` | Pacman hook (Arch, Manjaro, CachyOS...) |
| `/etc/apt/apt.conf.d/99apply-wayland-flags` | APT hook (Debian, Ubuntu, Pop!_OS...) |
| `/etc/dnf/plugins/post-transaction-actions.d/apply-wayland-flags.action` | DNF action (Fedora, RHEL...) |
| `/etc/zypp/plugins/commit/apply-wayland-flags` | Zypper hook (openSUSE) |

Mechanism applies regardless of shell (bash, zsh, fish) or terminal emulator — the script is installed to a directory in `$PATH`.

## Sudo vs --user

| | `sudo` (default) | `--user` | `--tui` |
|---|---|---|---|
| Script location | `/usr/local/bin/` (system-wide) | `~/.local/bin/` (per-user) | `~/.local/bin/` (per-user) |
| Package manager hook | Installed | Not installed | Not installed |
| Systemd path unit | Enabled | Enabled | Enabled |
| Clickable app menu entry | — | — | Added |

The package manager hook is optional — the systemd path unit detects new `.desktop` files within seconds via inotify regardless. The hook just provides instant application on package install.

## Flatpak support

Flatpak apps receive the flags via global environment overrides:

```
flatpak override --user --env=ELECTRON_EXTRA_LAUNCH_ARGS=...
flatpak override --user --env=CHROME_FLAGS=...
```

These are set once during installation and apply to all Flatpak apps (Electron and Chromium-based).

## Currently detected applications

<details>
<summary>Expand list</summary>

**Browsers:** Google Chrome, Chromium, Brave, Microsoft Edge, Vivaldi, Opera, Yandex Browser, Arc, Ungoogled Chromium, Iridium, Epic, Slimjet, Naver Whale, Cent Browser

**Editors/IDEs:** VS Code, VS Code OSS, VSCodium, Cursor, Antigravity, OpenCode

**Communication:** Discord, Slack, Microsoft Teams, Signal, WhatsApp, Mattermost, Zulip, Element, Keybase, Threema, Session

**Productivity:** Obsidian, Notion, Figma, Todoist, Postman, Insomnia, Standard Notes, Logseq, Spotify, Zoom, AnyDesk, TeamViewer

**Other:** GitHub Desktop, GitKraken, Joplin, Typora, MarkText, Ferdium, Ferdi, Vesktop, ArmCord, mongodb-compass

**Flatpak:** com.google.Chrome, org.chromium.Chromium, com.brave.Browser, com.microsoft.Edge, com.vivaldi.Vivaldi, com.opera.Opera, com.discordapp.Discord, com.slack.Slack, com.signal.Signal, com.visualstudio.code, md.obsidian.Obsidian, rest.insomnia.Insomnia, com.postman.Postman

</details>

### Requesting an app

If an app isn't detected, open an issue with:

1. The application name
2. Output of: `grep ^Exec /usr/share/applications/<name>.desktop`
3. For Flatpaks: `flatpak list --app --columns=application | grep -i <name>`

Or submit a PR adding the binary/Flatpak ID to the corresponding list in `apply-wayland-flags.sh`.

## Usage

```bash
# Full rescan — re-checks all installed applications
apply-wayland-flags --full

# Incremental — only processes new applications
apply-wayland-flags
```

`--full` clears existing overrides and re-scans everything. Use it after installing the script or when troubleshooting.

## Uninstall

```bash
sudo rm -f /usr/local/bin/apply-wayland-flags
rm -f ~/.local/share/applications/*.desktop
systemctl --user disable --now apply-wayland-flags.path
rm -f ~/.config/systemd/user/apply-wayland-flags.{service,path}
sudo rm -f /etc/pacman.d/hooks/apply-wayland-flags.hook
sudo rm -f /etc/apt/apt.conf.d/99apply-wayland-flags
sudo rm -f /etc/dnf/plugins/post-transaction-actions.d/apply-wayland-flags.action
flatpak override --user --unset-env=ELECTRON_EXTRA_LAUNCH_ARGS
flatpak override --user --unset-env=CHROME_FLAGS
```

## License

MIT
