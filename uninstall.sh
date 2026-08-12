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

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: uruchom jako root:"
    echo "  sudo ./uninstall.sh"
    exit 1
fi

echo "========================================"
echo " SAFE-UPDATE UNINSTALLER"
echo "========================================"

echo
echo "Stopping timer..."

systemctl disable --now safe-update.timer 2>/dev/null || true
systemctl stop safe-update.service 2>/dev/null || true

echo
echo "Removing systemd units..."

rm -f /etc/systemd/system/safe-update.service
rm -f /etc/systemd/system/safe-update.timer

systemctl daemon-reload

echo
echo "Removing program files..."

rm -rf "$INSTALL_DIR"

echo
echo "Program removed."
echo
echo "IMPORTANT:"
echo "Configuration and backups were NOT removed."
echo
echo "Preserved:"
echo "  $CONFIG_DIR"
echo "  $STATE_DIR"
echo "  $LOG_DIR"
echo
echo "If you really want to remove them manually:"
echo "  sudo rm -rf $CONFIG_DIR"
echo "  sudo rm -rf $STATE_DIR"
echo "  sudo rm -rf $LOG_DIR"
echo
echo "========================================"
echo "UNINSTALL COMPLETE"
echo "========================================"
