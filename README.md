# Echo SDDM

macOS Terminal-style SDDM login theme by xCaptaiN09.

## Requirements

- SDDM 0.20+
- Qt 6 + `qt6-5compat` — `sudo pacman -S qt6-5compat`
- Qt 5 users: replace `Qt5Compat.GraphicalEffects` with `QtGraphicalEffects 1.0` in `Main.qml`
- JetBrains Mono — `sudo pacman -S ttf-jetbrains-mono`

## Install

```bash
sudo cp -r echo-sddm /usr/share/sddm/themes/
```

Set in `/etc/sddm.conf` or `/etc/sddm.conf.d/theme.conf`:
```ini
[Theme]
Current=echo-sddm
```

## Configuration

Edit `/usr/share/sddm/themes/echo-sddm/theme.conf`:

| Key | Values | Default |
|-----|--------|---------|
| `type` | `pure` / `frosted` | `pure` |
| `login_mode` | `select` / `tty` | `select` |
| `background` | path to wallpaper | _(empty)_ |
| `font` | any installed monospace | `JetBrains Mono` |
| `font_size` | integer (pixels) | `14` |
| `boot_interval` | integer (ms per line) | `72` |

## Modes

**`login_mode=select`**
```
user:     captain  ◀ ▶
session:  hyprland ◀ ▶
password: _
```
Left/Right arrows cycle users and sessions. Tab moves between rows.

**`login_mode=tty`**
```
cupida login: _
Password: _

[F1] [F2] session: hyprland
```
Type username and password like a real TTY. F1/F2 switch session.

**`type=frosted`**
Set `background=` to an absolute path or a path relative to the theme directory.
```ini
type=frosted
background=assets/wallpaper.jpg
```

## Traffic Lights

| Button | Action |
|--------|--------|
| 🔴 Red | Shutdown |
| 🟡 Yellow | Reboot |
| 🟢 Green | Suspend |

## Real System Info

The sysinfo line reads live from disk:
- Hostname — `sddm.hostName`
- Distro — `/etc/os-release`
- Kernel — `/proc/version`
- Uptime — `/proc/uptime`
- Time — system clock
