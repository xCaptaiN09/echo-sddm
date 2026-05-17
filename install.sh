#!/bin/bash

# Echo SDDM - Universal Smart Installer
# Author: xCaptaiN09

set -e

THEME_NAME="echo"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==>${NC} Starting Echo SDDM Installation..."

# 1. DEPENDENCY CHECK
if ! command -v sddm-greeter-qt6 >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} sddm-greeter-qt6 not found. Install SDDM with Qt 6 support first."
    echo -e "   Arch: sudo pacman -S sddm"
    exit 1
fi

if ! pacman -Q qt6-5compat >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} qt6-5compat not found. Required for frosted glass blur."
    echo -e "   Arch: sudo pacman -S qt6-5compat"
    exit 1
fi

echo -e "${BLUE}==>${NC} Detected: ${GREEN}Qt6${NC} + ${GREEN}qt6-5compat${NC}"

# 2. NIXOS CHECK
if [ -f /etc/NIXOS ]; then
    echo -e "${RED}Warning:${NC} NixOS detected. Please use the declarative method in your config."
    exit 1
fi

# 3. ROOT CHECK
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} Please run as root (use sudo)."
    exit 1
fi

# 4. INSTALLATION
BACKUP_DIR=$(mktemp -d)

if [ -d "${THEME_DIR}" ]; then
    echo -e "${BLUE}==>${NC} Backing up user configurations..."
    [ -f "${THEME_DIR}/theme.conf" ] && cp "${THEME_DIR}/theme.conf" "${BACKUP_DIR}/"
    [ -f "${THEME_DIR}/assets/backgrounds/background.png" ] && cp "${THEME_DIR}/assets/backgrounds/background.png" "${BACKUP_DIR}/"
    [ -f "${THEME_DIR}/assets/backgrounds/background.jpg" ] && cp "${THEME_DIR}/assets/backgrounds/background.jpg" "${BACKUP_DIR}/"

    echo -e "${BLUE}==>${NC} Cleaning old version..."
    rm -rf "${THEME_DIR}"
fi

echo -e "${BLUE}==>${NC} Installing Echo to ${THEME_DIR}..."
mkdir -p "${THEME_DIR}/assets/backgrounds" "${THEME_DIR}/assets/screenshots"
cp -r Main.qml metadata.desktop theme.conf LICENSE "${THEME_DIR}/"
cp -r assets/* "${THEME_DIR}/assets/"
# Remove screenshots from installed theme (not needed at runtime)
rm -rf "${THEME_DIR}/assets/screenshots"
chmod -R 755 "${THEME_DIR}"

# Restore user configurations if they were backed up
if [ -f "${BACKUP_DIR}/theme.conf" ]; then
    echo -e "${BLUE}==>${NC} Restoring user configurations..."
    cp "${BACKUP_DIR}/theme.conf" "${THEME_DIR}/theme.conf"
    [ -f "${BACKUP_DIR}/background.png" ] && cp "${BACKUP_DIR}/background.png" "${THEME_DIR}/assets/backgrounds/background.png"
    [ -f "${BACKUP_DIR}/background.jpg" ] && cp "${BACKUP_DIR}/background.jpg" "${THEME_DIR}/assets/backgrounds/background.jpg"
    # Ensure use_24h option is present in older configs
    if ! grep -q "^use_24h=" "${THEME_DIR}/theme.conf"; then
        sed -i '/^boot_interval=/a use_24h=true' "${THEME_DIR}/theme.conf"
    fi
    if ! grep -q "^background_opacity=" "${THEME_DIR}/theme.conf"; then
        sed -i '/^boot_interval=/a background_opacity=0.78' "${THEME_DIR}/theme.conf"
    fi
    if ! grep -q "^blur_radius=" "${THEME_DIR}/theme.conf"; then
        sed -i '/^background_opacity=/a blur_radius=54' "${THEME_DIR}/theme.conf"
    fi
fi

rm -rf "${BACKUP_DIR}"

echo -e "${GREEN}Done!${NC} Echo SDDM is now installed."

# 5. CONFIGURATION
echo -e ""
read -p "Apply Echo as your active theme now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p /etc/sddm.conf.d
    echo -e "[Theme]\nCurrent=${THEME_NAME}" | tee /etc/sddm.conf.d/theme.conf > /dev/null
    echo -e "${GREEN}Theme applied successfully!${NC}"
else
    echo -e "To apply manually, set ${GREEN}Current=${THEME_NAME}${NC} in your SDDM config."
fi

echo -e ""
echo -e "Test with: ${BLUE}QML_XHR_ALLOW_FILE_READ=1 sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}${NC}"
