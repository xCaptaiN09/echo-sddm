# Echo SDDM

A macOS Terminal-inspired SDDM login theme. Dark monospace aesthetic, frosted glass, boot animation with real system data, and two login modes.

<div align="center">
  <img src="assets/screenshots/Screenshot_1.png" width="45%" />
  <img src="assets/screenshots/Screenshot_2.png" width="45%" />
</div>
<div align="center">
  <img src="assets/screenshots/Screenshot_3.png" width="45%" />
  <img src="assets/screenshots/Screenshot_4.png" width="45%" />
</div>

## Features

- **macOS Terminal UI:** Dark window with traffic light buttons (shutdown, reboot, suspend), title bar, and rounded corners.
- **Boot Animation:** systemd-style log lines with real hardware detection (CPU, RAM, modules, vendor) when available.
- **Two Background Modes:** Pure black or frosted glass (wallpaper + blur).
- **Two Login Modes:** Arrow-key user/session picker or TTY-style manual login.
- **System Info:** Hostname, distro, uptime, and date/time in the info bar.
- **Lock Indicators:** Caps Lock and Num Lock warnings inline.
- **Terminal-Style Errors:** Login failures show as inline red text, not centered banners.
- **24h/12h Clock:** Configurable via `theme.conf`.

---

## Prerequisites

- **Qt6** with **qt6-5compat** (for `FastBlur` and `OpacityMask`)
- SDDM **0.19+** with Qt6 greeter support
- JetBrains Mono font (or set a different font in `theme.conf`)

```bash
# Arch Linux
sudo pacman -S sddm qt6-5compat

# Fedora
sudo dnf install sddm qt6-qt5compat

# Debian 13/Testing
sudo apt install sddm libqt6quick6 libqt6qml6 qt6-5compat-dev
```

> **Note:** This theme is **Qt6-only**. It will not work with Qt5 SDDM.

---

## Installation

### Method A: Arch Linux (AUR)

```bash
yay -S echo-sddm-git
```

### Method B: Install Script

```bash
git clone https://github.com/xCaptaiN09/echo-sddm.git
cd echo-sddm
sudo ./install.sh
```

The script checks for `qt6-5compat`, backs up your existing config, installs the theme, and restores your settings.

### Method C: Manual

```bash
sudo mkdir -p /usr/share/sddm/themes/echo
sudo cp -r Main.qml metadata.desktop theme.conf install.sh LICENSE assets /usr/share/sddm/themes/echo/
```

Then set the theme:

```bash
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=echo" | sudo tee /etc/sddm.conf.d/theme.conf
```

---

## Testing

Preview without logging out:

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/echo
```

> **Note:** In test mode, `XMLHttpRequest` to local files is blocked by default. Use `QML_XHR_ALLOW_FILE_READ=1` if you want to see real CPU/RAM data in the boot log:
> ```bash
> QML_XHR_ALLOW_FILE_READ=1 sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/echo
> ```
> In real SDDM, `/proc` reads are blocked for security. The boot log falls back to hardcoded systemd-style lines.

---

## Qt6 Greeter

This theme declares `QtVersion=6` in `metadata.desktop`. SDDM 0.21+ will automatically use the Qt6 greeter (`sddm-greeter-qt6`).

If you are on an older SDDM or a distro that defaults to Qt5, force the Qt6 greeter:

```bash
sudo ln -sf /usr/bin/sddm-greeter-qt6 /usr/bin/sddm-greeter
```

---

## Configuration

Edit `/usr/share/sddm/themes/echo/theme.conf` (or edit before running `install.sh`):

| Option | Default | Description |
|--------|---------|-------------|
| `type` | `pure` | `pure` (black) or `frosted` (wallpaper + blur) |
| `login_mode` | `select` | `select` (arrow keys) or `tty` (type username) |
| `background` | `assets/backgrounds/background.png` | Wallpaper path for frosted mode |
| `font` | `JetBrains Mono` | Any installed monospace font |
| `font_size` | `14` | Font size in pixels |
| `boot_interval` | `72` | Milliseconds per boot log line |
| `use_24h` | `false` | `true` for 24h, `false` for 12h with AM/PM |
| `background_opacity` | `0.35` | Frosted glass opacity (0.1–1.0) |
| `blur_radius` | `54` | Blur strength for frosted mode (1–100) |

### Frosted Glass

```ini
type=frosted
background=assets/backgrounds/background.png
```

### TTY Mode

```ini
login_mode=tty
```

Type your username, press Enter, type password, press Enter to login. F1/F2 cycles sessions.

---

## Keyboard Controls

### Select Mode
| Key | Action |
|-----|--------|
| Left / Right | Cycle users or sessions |
| Tab / Down | Next row |
| Up / Shift+Tab | Previous row |
| Enter | Submit login |

### TTY Mode
| Key | Action |
|-----|--------|
| F1 / F2 | Cycle sessions |
| Enter | Submit field / login |
| Tab | Switch between username and password |

---

## Traffic Lights

| Button | Action |
|--------|--------|
| Red | Shutdown |
| Yellow | Reboot |
| Green | Suspend |

---

## Credits

- **Author:** [xCaptaiN09](https://github.com/xCaptaiN09)
- **Design:** Inspired by macOS Terminal.app
- **Font:** JetBrains Mono (system font, not bundled)

---

*MIT License*

---

*Made with ❤️ for the Linux community.*
