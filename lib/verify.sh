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

verify_tar() {
    local file="$1"

    tar -tzf "$file" >/dev/null
    echo "[OK] archive: $(basename "$file")"
}

verify_checksums() {
    local directory="$1"

    (
        cd "$directory"
        sha256sum -c SHA256SUMS
    )
}

verify_postgres_dump() {
    local service_user="$1"
    local container="$2"
    local dump_file="$3"

    local uid
    uid="$(id -u "$service_user")"

    echo "[CHECK] postgres dump: $(basename "$dump_file")"

    runuser -u "$service_user" -- \
        env XDG_RUNTIME_DIR="/run/user/$uid" \
        podman exec -i "$container" sh -c '
            tmp="$(mktemp /tmp/safe-update-db.XXXXXX)"
            trap '\''rm -f "$tmp"'\'' EXIT

            cat > "$tmp"
            pg_restore -l "$tmp" >/dev/null
        ' < "$dump_file"

    echo "[OK] postgres dump: $(basename "$dump_file")"
}
