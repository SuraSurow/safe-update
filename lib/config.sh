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

SAFE_UPDATE_CONFIG="/etc/safe-update/safe-update.conf"
SAFE_UPDATE_SERVICES_DIR="/etc/safe-update/services"

load_global_config() {
    if [[ ! -f "$SAFE_UPDATE_CONFIG" ]]; then
        echo "ERROR: brak konfiguracji:"
        echo "$SAFE_UPDATE_CONFIG"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$SAFE_UPDATE_CONFIG"
}

get_service_configs() {
    if [[ ! -d "$SAFE_UPDATE_SERVICES_DIR" ]]; then
        echo "ERROR: brak katalogu usług:"
        echo "$SAFE_UPDATE_SERVICES_DIR"
        return 1
    fi

    find "$SAFE_UPDATE_SERVICES_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -print \
        | sort
}
