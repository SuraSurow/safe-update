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

run_podman() {
    local user="$1"
    shift

    local uid
    uid="$(id -u "$user")"

    runuser -u "$user" -- \
        env XDG_RUNTIME_DIR="/run/user/$uid" \
        podman "$@"
}

backup_postgres() {
    local service_user="$1"
    local container="$2"
    local db_user="$3"
    local db_name="$4"
    local output="$5"

    echo "[DB] $db_name"

    run_podman "$service_user" exec "$container" \
        pg_dump -U "$db_user" -d "$db_name" -Fc \
        > "$output"

    [[ -s "$output" ]] || {
        echo "ERROR: pusty dump: $output"
        return 1
    }
}

backup_path() {
    local source="$1"
    local output="$2"

    [[ -d "$source" ]] || {
        echo "ERROR: brak katalogu: $source"
        return 1
    }

    echo "[FILES] $source"

    tar --numeric-owner -C "$source" -czf "$output" .

    [[ -s "$output" ]] || {
        echo "ERROR: puste archiwum: $output"
        return 1
    }
}

backup_volume() {
    local service_user="$1"
    local volume="$2"
    local output="$3"

    local mountpoint

    mountpoint="$(
        run_podman "$service_user" volume inspect "$volume" \
            --format '{{.Mountpoint}}'
    )"

    [[ -n "$mountpoint" ]] || {
        echo "ERROR: nie znaleziono volume: $volume"
        return 1
    }

    backup_path "$mountpoint" "$output"
}
