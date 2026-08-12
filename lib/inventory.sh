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

run_inventory() (
    set -euo pipefail

    local tmp_current
    local tmp_expected
    local config
    local expected
    local container
    local type
    local destination

    tmp_current="$(mktemp)"
    tmp_expected="$(mktemp)"

    trap 'rm -f "$tmp_current" "$tmp_expected"' EXIT

    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: inventory musi być uruchomiony jako root."
        return 1
    fi

    if ! declare -F get_service_configs >/dev/null 2>&1; then
        echo "ERROR: funkcja get_service_configs nie jest dostępna."
        return 1
    fi

    cd /tmp

    run_inventory_podman() {
        local user="$1"
        shift

        local uid
        uid="$(id -u "$user")"

        runuser -u "$user" -- \
            env XDG_RUNTIME_DIR="/run/user/$uid" \
            podman "$@"
    }

    while IFS= read -r config; do
        [[ -z "$config" ]] && continue

        unset SERVICE_NAME SERVICE_USER EXPECTED_MOUNTS
        declare -a EXPECTED_MOUNTS=()

        # shellcheck disable=SC1090
        source "$config"

        [[ -n "${SERVICE_NAME:-}" ]] || {
            echo "ERROR: brak SERVICE_NAME w $config"
            return 1
        }

        [[ -n "${SERVICE_USER:-}" ]] || {
            echo "ERROR: brak SERVICE_USER w $config"
            return 1
        }

        if ! id "$SERVICE_USER" >/dev/null 2>&1; then
            echo "ERROR: użytkownik $SERVICE_USER nie istnieje."
            return 1
        fi

        echo "Checking service: $SERVICE_NAME"

        for expected in "${EXPECTED_MOUNTS[@]}"; do
            echo "${SERVICE_USER}|${expected}" >> "$tmp_expected"
        done

        while IFS= read -r container; do
            [[ -z "$container" ]] && continue

            while IFS='|' read -r type destination; do
                [[ -z "$destination" ]] && continue

                echo "${SERVICE_USER}|${container}|${type}|${destination}" \
                    >> "$tmp_current"

            done < <(
                run_inventory_podman "$SERVICE_USER" inspect "$container" \
                    --format '{{range .Mounts}}{{.Type}}|{{.Destination}}{{"\n"}}{{end}}'
            )

        done < <(
            run_inventory_podman "$SERVICE_USER" ps --format '{{.Names}}'
        )

    done < <(get_service_configs)

    sort -o "$tmp_current" "$tmp_current"
    sort -o "$tmp_expected" "$tmp_expected"

    echo
    echo "=== SAFE-UPDATE MODULAR INVENTORY ==="
    echo

    if diff -u "$tmp_expected" "$tmp_current"; then
        echo
        echo "PASS: wszystkie persistent mounty są zgodne z konfiguracją."
        return 0
    else
        echo
        echo "FAIL: wykryto zmianę persistent storage."
        echo "SAFE-UPDATE MUSI zostać zatrzymany."
        return 1
    fi
)
