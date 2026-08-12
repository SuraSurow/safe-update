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

apply_retention() {
    local backup_base="$1"
    local retention_count="${BACKUP_RETENTION:-7}"
    local count
    local i

    if ! [[ "$retention_count" =~ ^[0-9]+$ ]] || (( retention_count < 1 )); then
        echo "ERROR: nieprawidłowe BACKUP_RETENTION: $retention_count"
        return 1
    fi

    if [[ ! -d "$backup_base" ]]; then
        echo "ERROR: katalog backupów nie istnieje: $backup_base"
        return 1
    fi

    mapfile -t backups < <(
        find "$backup_base" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%T@ %p\n' |
        sort -nr |
        awk '{print $2}'
    )

    count="${#backups[@]}"

    if (( count <= retention_count )); then
        echo "[RETENTION] $count backup(s) present — nothing to remove."
        echo "[RETENTION] limit: $retention_count"
        return 0
    fi

    echo "[RETENTION] keeping newest $retention_count backups."

    for (( i=retention_count; i<count; i++ )); do
        echo "[RETENTION] removing: ${backups[$i]}"
        rm -rf -- "${backups[$i]}"
    done
}

get_safe_update_snapshots() {
    local snapshot_device="${TIMESHIFT_DEVICE:-}"

    if [[ -z "$snapshot_device" ]]; then
        echo "ERROR: TIMESHIFT_DEVICE nie jest ustawione." >&2
        return 1
    fi

    timeshift --list \
        --snapshot-device "$snapshot_device" |
    awk '
        $3 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$/ &&
        $0 ~ /pre-update-/ {
            print $3
        }
    ' |
    sort -r
}

preview_snapshot_retention() {
    local retention_count="${SNAPSHOT_RETENTION:-5}"
    local count
    local i

    if ! [[ "$retention_count" =~ ^[0-9]+$ ]] || (( retention_count < 1 )); then
        echo "ERROR: nieprawidłowe SNAPSHOT_RETENTION: $retention_count"
        return 1
    fi

    mapfile -t snapshots < <(get_safe_update_snapshots)

    count="${#snapshots[@]}"

    echo "=== SNAPSHOT RETENTION PREVIEW ==="
    echo "Configured retention: $retention_count"
    echo "Safe-update snapshots found: $count"
    echo

    if (( count <= retention_count )); then
        echo "Nothing would be removed."
        return 0
    fi

    echo "Snapshots that WOULD be removed:"

    for (( i=retention_count; i<count; i++ )); do
        echo "  ${snapshots[$i]}"
    done
}

apply_snapshot_retention() {
    local retention_count="${SNAPSHOT_RETENTION:-5}"
    local snapshot_device="${TIMESHIFT_DEVICE:-}"
    local count
    local i
    local snapshot

    if [[ -z "$snapshot_device" ]]; then
        echo "ERROR: TIMESHIFT_DEVICE nie jest ustawione."
        return 1
    fi

    if ! [[ "$retention_count" =~ ^[0-9]+$ ]] || (( retention_count < 1 )); then
        echo "ERROR: nieprawidłowe SNAPSHOT_RETENTION: $retention_count"
        return 1
    fi

    mapfile -t snapshots < <(get_safe_update_snapshots)

    count="${#snapshots[@]}"

    if (( count <= retention_count )); then
        echo "[SNAPSHOT RETENTION] $count snapshot(s) present — nothing to remove."
        echo "[SNAPSHOT RETENTION] limit: $retention_count"
        return 0
    fi

    echo "[SNAPSHOT RETENTION] keeping newest $retention_count safe-update snapshots."

    for (( i=retention_count; i<count; i++ )); do
        snapshot="${snapshots[$i]}"

        echo "[SNAPSHOT RETENTION] removing: $snapshot"

        timeshift --delete \
            --snapshot "$snapshot" \
            --snapshot-device "$snapshot_device"
    done
}
