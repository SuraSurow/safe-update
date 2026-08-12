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

UPDATE_WORKDIR="/var/lib/safe-update/update-check"

mkdir -p "$UPDATE_WORKDIR"

check_updates() {
    local run_dir="$1"

    mkdir -p "$run_dir"

    local raw="$run_dir/upgradable-raw.txt"
    local planned="$run_dir/planned-upgrades.txt"
    local risk="$run_dir/risk-report.txt"
    local count
    local package
    local risk_level

    echo "=== APT UPDATE ==="

    apt-get update

    echo
    echo "=== AVAILABLE UPDATES ==="

    apt list --upgradable 2>/dev/null \
        | tail -n +2 \
        | sort \
        > "$raw"

    count="$(wc -l < "$raw")"
    echo "$count" > "$run_dir/update-count"

    if [[ "$count" -eq 0 ]]; then
        echo "NONE" > "$run_dir/risk-level"
        echo "No updates available."
        return 0
    fi

    {
        echo "# Planned package upgrades"
        echo
        echo "Date: $(date -Is)"
        echo "Host: $(hostname)"
        echo "Count: $count"
        echo
        cat "$raw"
    } > "$planned"

    echo "Updates available: $count"
    echo
    cat "$raw"

    echo
    echo "=== RISK CLASSIFICATION ==="

    : > "$risk"

    while IFS= read -r line; do

        package="${line%%/*}"
        risk_level="LOW"

        case "$package" in
            linux-image-*|linux-headers-*|linux-base|linux-libc-dev)
                risk_level="HIGH:KERNEL"
                ;;

            systemd|systemd-*|libsystemd*)
                risk_level="HIGH:SYSTEMD"
                ;;

            openssh-server|openssh-client|openssh-sftp-server)
                risk_level="HIGH:SSH"
                ;;

            nftables|libnftables*|libnftnl*)
                risk_level="HIGH:FIREWALL"
                ;;

            podman|conmon|crun|runc|containers-common)
                risk_level="HIGH:CONTAINERS"
                ;;

            nginx|nginx-*|nginx-common)
                risk_level="HIGH:WEB"
                ;;

            postgresql*|libpq*)
                risk_level="HIGH:DATABASE"
                ;;

            libc6|libc-bin|libc-dev-bin)
                risk_level="HIGH:LIBC"
                ;;

            docker*|containerd*)
                risk_level="HIGH:CONTAINERS"
                ;;

            *)
                risk_level="LOW"
                ;;
        esac

        printf '%-25s %s\n' "$risk_level" "$package" >> "$risk"

    done < "$raw"

    cat "$risk"

    if grep -q '^HIGH:' "$risk"; then
        echo "HIGH" > "$run_dir/risk-level"
    else
        echo "LOW" > "$run_dir/risk-level"
    fi

    return 0
}
