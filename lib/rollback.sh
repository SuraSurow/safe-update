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

rollback_snapshot() {
    local snapshot_name="$1"

    if [[ -z "${TIMESHIFT_DEVICE:-}" ]]; then
        echo "ERROR: TIMESHIFT_DEVICE nie jest ustawione."
        return 1
    fi

    if [[ -z "$snapshot_name" ]]; then
        echo "ERROR: brak nazwy snapshotu."
        return 1
    fi

    local snapshot_path="/timeshift/snapshots/$snapshot_name"

    if [[ ! -d "$snapshot_path" ]]; then
        echo "ERROR: snapshot nie istnieje:"
        echo "$snapshot_path"
        return 1
    fi

    echo "========================================"
    echo " SAFE-UPDATE ROLLBACK"
    echo " Snapshot: $snapshot_name"
    echo " Device:   $TIMESHIFT_DEVICE"
    echo "========================================"

    echo
    echo "WARNING:"
    echo "System zostanie przywrócony do stanu sprzed update."
    echo "Timeshift przywróci system i wykona reboot."
    echo

    timeshift --restore \
        --snapshot "$snapshot_name" \
        --snapshot-device "$TIMESHIFT_DEVICE" \
        --scripted
}
