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

run_system_update() {
    local run_dir="$1"

    mkdir -p "$run_dir"

    local simulation="$run_dir/apt-simulation.log"
    local update_log="$run_dir/apt-upgrade.log"

    echo
    echo "=== APT SIMULATION ==="

    apt-get --simulate upgrade > "$simulation"

    echo "[OK] apt simulation completed"

    if grep -q '^Remv ' "$simulation"; then
        echo "ERROR: simulation wants to remove packages."
        echo "Update aborted."
        return 1
    fi

    echo
    echo "=== APT UPGRADE ==="

    DEBIAN_FRONTEND=noninteractive \
    apt-get -y upgrade \
        2>&1 | tee "$update_log"

    echo
    echo "APT UPDATE: PASS"
}

