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

create_system_snapshot() {
    local run_dir="$1"
    local label
    local before_file
    local after_file
    local snapshot_name
    local snapshot_path

    if [[ -z "${TIMESHIFT_DEVICE:-}" ]]; then
        echo "ERROR: TIMESHIFT_DEVICE nie jest ustawione."
        return 1
    fi

    mkdir -p "$run_dir"

    label="pre-update-$(date '+%Y-%m-%d_%H-%M-%S')"

    before_file="$run_dir/timeshift-before.txt"
    after_file="$run_dir/timeshift-after.txt"

    echo "=== SYSTEM SNAPSHOT ==="
    echo "Creating Timeshift snapshot..."
    echo "Device: $TIMESHIFT_DEVICE"
    echo "Label:  $label"

    timeshift --list \
        --snapshot-device "$TIMESHIFT_DEVICE" \
        > "$before_file"

    timeshift --create \
        --rsync \
        --snapshot-device "$TIMESHIFT_DEVICE" \
        --comments "$label"

    timeshift --list \
        --snapshot-device "$TIMESHIFT_DEVICE" \
        > "$after_file"

    snapshot_name="$(
        awk -v label="$label" '
            index($0, label) {
                print $3
                exit
            }
        ' "$after_file"
    )"

    if [[ -z "$snapshot_name" ]]; then
        echo "ERROR: nie udało się ustalić nazwy snapshotu."
        return 1
    fi

    snapshot_path="/timeshift/snapshots/$snapshot_name"

    if [[ ! -d "$snapshot_path" ]]; then
        echo "ERROR: snapshot nie istnieje:"
        echo "$snapshot_path"
        return 1
    fi

    echo "$snapshot_name" > "$run_dir/system-snapshot-name"
    echo "$label" > "$run_dir/system-snapshot-label"

    du -sh "$snapshot_path" \
        > "$run_dir/system-snapshot-size.txt"

    echo
    echo "SYSTEM SNAPSHOT: PASS"
    echo "Name: $snapshot_name"
    echo "Label: $label"
    echo "Path: $snapshot_path"
}
