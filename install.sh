#!/bin/bash

# Safe Update
# Copyright (C) 2026 Wojciech Surowiecki
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.

set -euo pipefail

INSTALL_DIR="/opt/safe-update"
CONFIG_DIR="/etc/safe-update"
STATE_DIR="/var/lib/safe-update"
LOG_DIR="/var/log/safe-update"
SYSTEMD_DIR="/etc/systemd/system"

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd
)"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: uruchom installer jako root:"
    echo "  sudo ./install.sh"
    exit 1
fi

echo "========================================"
echo " SAFE-UPDATE INSTALLER"
echo "========================================"

echo
echo "=== CHECK DEPENDENCIES ==="

required_commands=(
    apt-get
    awk
    curl
    df
    find
    grep
    rsync
    sha256sum
    sort
    tar
    timeshift
)

missing=()

for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK] $cmd"
    else
        echo "[MISSING] $cmd"
        missing+=("$cmd")
    fi
done

if (( ${#missing[@]} > 0 )); then
    echo
    echo "Installing required packages..."

    apt-get update

    apt-get install -y \
        curl \
        rsync \
        timeshift
fi

echo
echo "=== INSTALL PROGRAM ==="

mkdir -p "$INSTALL_DIR/lib"

install -o root -g root -m 700 \
    "$SCRIPT_DIR/safe-update" \
    "$INSTALL_DIR/safe-update"

for file in "$SCRIPT_DIR"/lib/*.sh; do
    install -o root -g root -m 700 \
        "$file" \
        "$INSTALL_DIR/lib/"
done

echo "[OK] program installed in $INSTALL_DIR"

echo
echo "=== CONFIGURATION ==="

mkdir -p "$CONFIG_DIR/services"

chmod 700 "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR/services"
chown root:root "$CONFIG_DIR" "$CONFIG_DIR/services"

if [[ ! -f "$CONFIG_DIR/safe-update.conf" ]]; then

    install -o root -g root -m 600 \
        "$SCRIPT_DIR/config/safe-update.conf.example" \
        "$CONFIG_DIR/safe-update.conf"

    echo "[OK] created $CONFIG_DIR/safe-update.conf"

else
    echo "[SKIP] existing safe-update.conf preserved"
fi

echo
echo "=== DATA DIRECTORIES ==="

mkdir -p \
    "$STATE_DIR/backups" \
    "$STATE_DIR/update-check" \
    "$LOG_DIR"

chown -R root:root "$STATE_DIR" "$LOG_DIR"
chmod 700 "$STATE_DIR"
chmod 700 "$STATE_DIR/backups"
chmod 700 "$STATE_DIR/update-check"
chmod 700 "$LOG_DIR"

echo "[OK] data directories created"

echo
echo "=== SYSTEMD ==="

install -o root -g root -m 644 \
    "$SCRIPT_DIR/systemd/safe-update.service" \
    "$SYSTEMD_DIR/safe-update.service"

install -o root -g root -m 644 \
    "$SCRIPT_DIR/systemd/safe-update.timer" \
    "$SYSTEMD_DIR/safe-update.timer"

systemctl daemon-reload

echo "[OK] systemd units installed"

echo
echo "========================================"
echo "INSTALLATION COMPLETE"
echo
echo "Next steps:"
echo
echo "1. Edit:"
echo "   $CONFIG_DIR/safe-update.conf"
echo
echo "2. Add service configs to:"
echo "   $CONFIG_DIR/services/"
echo
echo "3. Test:"
echo "   sudo $INSTALL_DIR/safe-update check"
echo
echo "4. Enable automatic updates when ready:"
echo "   sudo systemctl enable --now safe-update.timer"
echo "========================================"
