# apply-wayland-flags

¿Tienes textos borrosos, parpadeos o glitches en aplicaciones como Chrome, VS Code, Discord, Cursor, etc., al usar Wayland con escalado fraccionario (125%, 150%)? **Este script lo soluciona automáticamente.**

## ¿Por qué pasa esto?

Las aplicaciones basadas en **Electron** (VS Code, Discord, Slack, Cursor, Obsidian...) y **Chromium** (Chrome, Brave, Edge, Opera...) tienen un problema con el escalado fraccionario en Wayland. Por defecto usan un protocolo que causa textos borrosos y parpadeos.

**La solución** es pasarles dos banderas (flags) al iniciarlas:

```
--disable-features=WaylandFractionalScaleV1 --ozone-platform-hint=wayland
```

Este script **detecta automáticamente** qué apps necesitan esas banderas y las aplica por ti, incluyendo las que instales en el futuro.

## Instalación

### Opción 1: Para todo el sistema (recomendada, pide contraseña)

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash
```

Pide tu contraseña de sudo para:
- Copiar el script a `/usr/local/bin/` (para que esté disponible para todos los usuarios)
- Instalar el **hook** del gestor de paquetes (para que al instalar una app nueva, se apliquen los flags automáticamente)

### Opción 2: Solo para tu usuario (sin contraseña)

```bash
curl -sSfL https://raw.githubusercontent.com/ElMeGGa-14/apply-wayland-flags/main/install.sh | bash -s -- --user
```

- Copia el script a `~/.local/bin/` (solo tú puedes usarlo)
- **No** instala hooks del gestor de paquetes (pero igual detecta apps nuevas por sí solo)

### ¿Cuál elijo?

| | Opción 1 (sudo) | Opción 2 (--user) |
|---|---|---|
| Pide contraseña | ✅ Sí | ❌ No |
| Disponible para | Todos los usuarios del PC | Solo tu usuario |
| Detecta apps al instalarlas | ✅ Sí (hook + watcher) | ✅ Sí (solo watcher) |
| Lo recomiendo si... | Eres el único usuario o admin del PC | No tienes acceso a sudo |

Si no sabes cuál elegir, usa la **Opción 1**.

## ¿Funciona en mi distro?

Sí. Funciona en **cualquier distribución de Linux**:

| Distro | ¿Cómo detecta apps nuevas automáticamente? |
|---|---|
| **Arch Linux, Manjaro, CachyOS, EndeavourOS** | Hook de pacman + watcher |
| **Debian, Ubuntu, Mint, Pop!_OS, Kali** | Hook de APT + watcher |
| **Fedora, RHEL, CentOS** | Hook de DNF + watcher |
| **openSUSE** | Hook de Zypper + watcher |
| **Cualquier otra** | Solo watcher (sigue funcionando, solo que el watcher tarda unos segundos en detectar la app nueva) |

El **watcher** (systemd path unit) es un vigilante que no consume recursos (usa inotify, 0% CPU cuando está en reposo). Cuando detecta que apareció un archivo `.desktop` nuevo, ejecuta el script automáticamente.

## ¿Funciona en mi terminal?

Sí. **No importa qué terminal uses** (kitty, alacritty, gnome-terminal, konsole, xterm...) ni **qué shell** (bash, zsh, fish...). El script se instala en `/usr/local/bin/` (o `~/.local/bin/`), que es una carpeta especial que **todos los programas de terminal** revisan cuando escribes un comando.

Después de instalar, puedes ejecutarlo desde cualquier terminal con:

```bash
apply-wayland-flags --full
```

## ¿Qué apps están cubiertas?

El script detecta automáticamente estas apps (y muchas más no listadas, porque también inspecciona los archivos directamente):

**Navegadores:** Google Chrome, Chromium, Brave, Edge, Vivaldi, Opera, Yandex Browser, Arc, Ungoogled Chromium, Iridium, Epic, Slimjet, Naver Whale, Cent Browser

**Programas de código / editores:** VS Code, VS Code OSS, VSCodium, Cursor, Antigravity, OpenCode

**Chats / Comunicación:** Discord, Slack, Microsoft Teams, Signal, WhatsApp, Mattermost, Zulip, Element, Keybase, Threema, Session

**Productividad:** Obsidian, Notion, Figma, Todoist, Postman, Insomnia, Standard Notes, Logseq, Spotify, Zoom, AnyDesk, TeamViewer

**Otros:** GitHub Desktop, GitKraken, Joplin, Typora, MarkText, Ferdium, Ferdi, Vesktop, ArmCord, mongodb-compass

**Apps Flatpak:** Google Chrome, Chromium, Brave, Edge, Vivaldi, Opera, Discord, Slack, Signal, VS Code, Obsidian, Insomnia, Postman (además de los overrides globales que cubren cualquier otra app Flatpak que uses en el futuro)

### ¿Falta una app?

Si instalaste una app y los textos siguen borrosos, puede que no esté en la lista. Pide que la agreguemos abriendo un **issue** en GitHub con:

1. El nombre de la app
2. La salida de este comando (explica qué binario usa):

```bash
cat /usr/share/applications/nombre-de-la-app.desktop | grep ^Exec
```

Por ejemplo, para Cursor sería:
```
Exec=/usr/share/cursor/cursor %F
```

También puedes hacerlo tú mismo: agrega el nombre a las listas `KNOWN_BINARIES` o `KNOWN_FLATPAK_IDS` en `apply-wayland-flags.sh` y haz un PR. Es solo agregar el nombre del programa.

## ¿Cómo funciona por dentro? (para curiosos)

1. **Escanea** los archivos `.desktop` de tus programas instalados (`/usr/share/applications/` y carpetas de Flatpak)
2. **Detecta** cuáles son apps Electron/Chromium de 4 formas:
   - Compara el nombre del programa con su lista conocida
   - Revisa si el nombre del archivo `.desktop` coincide
   - Busca las palabras "electron", "chromium" o "chrome" en la ruta del programa
   - Si el programa es un archivo binario (ELF), lo inspecciona por dentro buscando referencias a Electron/Chromium (esto funciona incluso si el programa está comprimido o empaquetado)
3. **Crea una copia** del `.desktop` en `~/.local/share/applications/` con las banderas agregadas (las copias locales tienen prioridad sobre las del sistema)
4. **Para Flatpak**: configura variables de entorno globales para que todas las apps Flatpak reciban las banderas

## Como desinstalar

Si ya no lo necesitas:

```bash
# 1. Borra el script
sudo rm -f /usr/local/bin/apply-wayland-flags

# 2. Borra las copias de los .desktop que creó
rm -f ~/.local/share/applications/*.desktop
# O si quieres conservar algunas: borra solo /usr/local/share/applications/

# 3. Desactiva el watcher
systemctl --user disable --now apply-wayland-flags.path

# 4. Borra los archivos del watcher
rm -f ~/.config/systemd/user/apply-wayland-flags.{service,path}

# 5. (Opcional) Borra el hook del gestor de paquetes
sudo rm -f /etc/pacman.d/hooks/apply-wayland-flags.hook
sudo rm -f /etc/apt/apt.conf.d/99apply-wayland-flags
sudo rm -f /etc/dnf/plugins/post-transaction-actions.d/apply-wayland-flags.action

# 6. (Opcional) Borra los overrides globales de Flatpak
flatpak override --user --unset-env=ELECTRON_EXTRA_LAUNCH_ARGS
flatpak override --user --unset-env=CHROME_FLAGS
```

## Licencia

MIT
