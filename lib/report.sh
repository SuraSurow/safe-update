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

generate_report() {
    local dest="$1"
    local started="$2"
    local finished="$3"

    local report="$dest/report.md"
    local total_size

    total_size="$(du -sh "$dest" | awk '{print $1}')"

    {
        echo "# Safe Update Backup Report"
        echo
        echo "- Start: $started"
        echo "- Finish: $finished"
        echo "- Status: PASS"
        echo "- Total size: $total_size"
        echo "- Host: $(hostname)"
        echo
        echo "## Services"
        echo

        for service_dir in "$dest"/*/; do
    		[[ -d "$service_dir" ]] || continue

    		service_dir="${service_dir%/}"
    		service="$(basename "$service_dir")"

            echo "### $service"
            echo
            echo '```text'
            du -sh "$service_dir"/* 2>/dev/null || true
            echo '```'
            echo
        done

        echo "## Verification"
        echo
        echo "- Persistent mount inventory: PASS"
        echo "- PostgreSQL dump verification: PASS"
        echo "- TAR archive verification: PASS"
        echo "- SHA256 verification: PASS"
        echo
        echo "## Files"
        echo
        echo '```text'
        find "$dest" -type f -printf '%P\n' | sort
        echo '```'

    } > "$report"
}
