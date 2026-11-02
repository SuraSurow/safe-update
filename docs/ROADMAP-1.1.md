# Safe Update 1.1 — Adaptive Update Engine (development plan)

Status: design / development branch. **Not production-ready.** Do not deploy on a production host until tested.

## Goals

- Preserve the existing manual backup and Timeshift-based rollback workflow.
- Default to read-only planning: no package installation, service restart, or reboot during `plan`.
- Classify **the actual APT simulation**, rather than only parsing `apt list --upgradable`.
- Explicit policy gates for kernel, SSH, VPN/networking, firewall, Podman, databases, systemd and bootloader changes.
- Reconcile health checks with intentional restrictions (VPN, HTTP 401/403) without silently ignoring unexpected failures.
- Require recoverability evidence (verified backups, boot partitions, rescue-console access) before upgrades.
- Never reboot or auto-rollback unless separately authorized.

## Proposed commands

| Command | Intent |
|---|---|
| `safe-update plan` | Gather evidence, simulate APT, calculate risk, emit machine-readable plan; no upgrades |
| `safe-update doctor` | Run host and service diagnostics without upgrading |
| `safe-update backup` | Back up only configured assets; verify archives and dump integrity |
| `safe-update apply --plan <id>` | Execute a current, approved plan with preflight gates |
| `safe-update status` | Summarize last run, pending reboot and backup status |
| `safe-update rollback <snapshot>` | Explicit operator-controlled recovery |

Existing `check` and `run` require a compatibility/migration decision before release.

## Adaptive policy sketch

- LOW: optional automatic application within maintenance window, only after tests pass.
- MEDIUM: service restart and dependency impact analysis, manual approval by default.
- HIGH: kernel, init/systemd, SSH, VPN, firewall, container runtime, bootloader, database runtime or package removals. Never unattended by default.
- UNKNOWN: fail closed until classified.

These are proposed classifications, not a correctness guarantee. The solver plan and environment matter.

## Health-check redesign

Each service should declare:
- type (systemd, podman, postgres, http, custom)
- criticality (critical / warning / informational)
- expected behavior and acceptable HTTP codes
- local health endpoint or private network context
- timeout and retry policy

Do not globally ignore failed systemd units; support an explicit audited allowlist with reasons/expiry.
For HTTP, accepting 403 by policy proves the access control responds, **not** application health. Combine with local checks.

## Data protection

- Record package versions, APT simulation and plan digest.
- Inventory persistent mounts and bind paths; avoid treating running containers' current mounts as a complete backup manifest.
- Validate PostgreSQL logical dumps and run periodic **test restores** in an isolated environment.
- Verify backup location, free capacity, and availability outside the host.
- Validate Timeshift behavior across /, /boot, /boot/efi; arrange provider snapshots or rescue console for boot failures.
- Preserve backups/snapshots on failures. Retention only after validated success and separate policy checks.

## Execution safety

- Single-run lock (`flock`) and explicit stages.
- Atomic, timestamped JSON and text logs, with clear exit codes.
- Refuse stale plans or changed APT candidate versions.
- Never assume `apt-get -s upgrade` means no service disruptions.
- Upgrade only in an approved maintenance window; provide explicit reboot-needed reporting.
- Post-update checks for sshd, WireGuard path, nginx, Zabbix, Podman containers and databases.
- Preserve existing `main` branch and production installation.

## Testing requirements

1. ShellCheck + bash syntax checks and mocked APT/Podman/Timeshift calls.
2. Tests for 403 on protected public endpoints versus healthy local endpoints.
3. Tests for failed non-critical systemd services and unknown critical failures.
4. Tests for APT plan changes, package removals, held packages, new kernel and reboot requirement.
5. Missing/corrupt backup, disk-full, PostgreSQL restore failure.
6. Interrupted update, stale lock and failure before/after snapshot.
7. Real isolated Debian 13 virtual machine with rootless Podman.
8. Restore drill from separate root, /boot and EFI partitions.
9. Supervised canary deployment; production timer kept disabled until acceptance.

## Proposed implementation order

1. Tests and audit fixes.
2. `plan` command and structured risk policies.
3. Pluggable health checks and expected-access restrictions.
4. Backup manifest, integrity and recovery evidence.
5. Approval gates and `apply`.
6. Documentation, upgrade guide and 1.1 release candidate.

**No implementation of these features is implied by this document.**
