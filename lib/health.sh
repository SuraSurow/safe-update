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



run_podman_health() {
    local user="$1"
    shift

    local uid
    uid="$(id -u "$user")"

    (
        cd /tmp

        runuser -u "$user" -- \
            env XDG_RUNTIME_DIR="/run/user/$uid" \
            podman "$@"
    )
}


health_ok() {
    echo "[OK] $1"
}

health_fail() {
    echo "[FAIL] $1"
    HEALTH_FAILURES=$((HEALTH_FAILURES + 1))
}

health_skip() {
    echo "[SKIP] $1"
}

check_host_health() {
    local disk_usage
    local mem_available_kb
    local mem_available_mb
    local disk_limit="${ROOT_DISK_MAX_PERCENT:-90}"
    local memory_limit="${MIN_AVAILABLE_MEMORY_MB:-256}"

    echo
    echo "=== HOST HEALTH ==="

    #
    # SYSTEMD
    #

    if [[ -z "$(systemctl --failed --no-legend 2>/dev/null)" ]]; then
        health_ok "systemd: no failed units"
    else
        health_fail "systemd: failed units detected"
        systemctl --failed --no-pager || true
    fi

    #
    # NGINX
    #

    if command -v nginx >/dev/null 2>&1 || [[ -x /usr/sbin/nginx ]]; then

        if /usr/sbin/nginx -t >/dev/null 2>&1; then
            health_ok "nginx configuration"
        else
            health_fail "nginx configuration"
            /usr/sbin/nginx -t || true
        fi

        if systemctl is-active --quiet nginx; then
            health_ok "nginx service active"
        else
            health_fail "nginx service inactive"
        fi

    else
        health_skip "nginx not installed"
    fi

    #
    # NFTABLES
    #

    if command -v nft >/dev/null 2>&1; then

        if nft list ruleset >/dev/null 2>&1; then
            health_ok "nftables ruleset readable"
        else
            health_fail "nftables ruleset"
        fi

    else
        health_skip "nftables not installed"
    fi

    #
    # DISK
    #

    disk_usage="$(
        df --output=pcent / \
        | tail -1 \
        | tr -dc '0-9'
    )"

    if [[ "$disk_usage" -lt "$disk_limit" ]]; then
        health_ok "root filesystem usage: ${disk_usage}% (< ${disk_limit}%)"
    else
        health_fail "root filesystem usage: ${disk_usage}% (limit: ${disk_limit}%)"
    fi

    #
    # MEMORY
    #

    mem_available_kb="$(
        awk '/MemAvailable:/ {print $2}' /proc/meminfo
    )"

    mem_available_mb=$((mem_available_kb / 1024))

    if [[ "$mem_available_mb" -gt "$memory_limit" ]]; then
        health_ok "available RAM: ${mem_available_mb} MB (> ${memory_limit} MB)"
    else
        health_fail "available RAM: ${mem_available_mb} MB (limit: ${memory_limit} MB)"
    fi
}

check_service_health() {
    local config="$1"

    unset \
        SERVICE_NAME SERVICE_USER \
        DB_TYPE DB_CONTAINER DB_NAME DB_USER \
        BACKUP_PATHS BACKUP_VOLUMES \
        EXPECTED_MOUNTS HEALTH_URL

    declare -a BACKUP_PATHS=()
    declare -a BACKUP_VOLUMES=()
    declare -a EXPECTED_MOUNTS=()

    # shellcheck disable=SC1090
    source "$config"

    [[ -n "${SERVICE_NAME:-}" ]] || {
        health_fail "SERVICE_NAME missing in $config"
        return
    }

    [[ -n "${SERVICE_USER:-}" ]] || {
        health_fail "SERVICE_USER missing in $config"
        return
    }

    echo
    echo "=== SERVICE: $SERVICE_NAME ==="

    #
    # USER
    #

    if id "$SERVICE_USER" >/dev/null 2>&1; then
        health_ok "$SERVICE_USER exists"
    else
        health_fail "$SERVICE_USER missing"
        return
    fi

    #
    # PODMAN
    #

    if run_podman_health "$SERVICE_USER" info >/dev/null 2>&1; then
        health_ok "Podman accessible"
    else
        health_fail "Podman inaccessible"
        return
    fi

    #
    # CONTAINERS
    #

    local containers
    local container
    local state

    containers="$(
        run_podman_health "$SERVICE_USER" ps -a \
            --format '{{.Names}}'
    )"

    if [[ -z "$containers" ]]; then
        health_fail "no containers found"
    else

        while IFS= read -r container; do
            [[ -z "$container" ]] && continue

            state="$(
                run_podman_health "$SERVICE_USER" inspect "$container" \
                    --format '{{.State.Status}}'
            )"

            if [[ "$state" == "running" ]]; then
                health_ok "container $container: running"
            else
                health_fail "container $container: $state"
            fi

        done <<< "$containers"

    fi

    #
    # DATABASE
    #

    case "${DB_TYPE:-none}" in

        postgres)
            if run_podman_health "$SERVICE_USER" exec "$DB_CONTAINER" \
                psql \
                -U "$DB_USER" \
                -d "$DB_NAME" \
                -tAc 'SELECT 1;' \
                2>/dev/null \
                | grep -qx '1'
            then
                health_ok "PostgreSQL $DB_NAME: SELECT 1"
            else
                health_fail "PostgreSQL $DB_NAME"
            fi
            ;;

        none)
            health_skip "database check"
            ;;

        *)
            health_fail "unsupported DB_TYPE: $DB_TYPE"
            ;;
    esac

    #
    # OPTIONAL HTTP TEST
    #

    if [[ -n "${HEALTH_URL:-}" ]]; then

        if curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --max-time 10 \
            "$HEALTH_URL" \
            >/dev/null
        then
            health_ok "HTTP: $HEALTH_URL"
        else
            health_fail "HTTP: $HEALTH_URL"
        fi

    else
        health_skip "HTTP test: HEALTH_URL not configured"
    fi
}

run_health_check() {
    local run_dir="$1"
    local stage="${2:-unknown}"
    local log
    local summary
    local config
    local HEALTH_FAILURES=0

    mkdir -p "$run_dir"

    log="$run_dir/health-${stage}.log"
    summary="$run_dir/health-${stage}.status"

    {
        echo "========================================"
        echo " SAFE-UPDATE HEALTH CHECK"
        echo " Stage: $stage"
        echo " Date: $(date -Is)"
        echo " Host: $(hostname)"
        echo "========================================"

        check_host_health

        while IFS= read -r config; do
            [[ -z "$config" ]] && continue
            check_service_health "$config"
        done < <(get_service_configs)

        echo
        echo "========================================"

        if [[ "$HEALTH_FAILURES" -eq 0 ]]; then
            echo "HEALTH CHECK: PASS"
            echo "Failures: 0"
            echo "PASS" > "$summary"
            echo "========================================"
            return 0
        else
            echo "HEALTH CHECK: FAIL"
            echo "Failures: $HEALTH_FAILURES"
            echo "FAIL" > "$summary"
            echo "========================================"
            return 1
        fi

    } 2>&1 | tee "$log"
}
