# Safe Update

**Safe Update** is a modular update, backup, health-check and rollback framework for Debian servers.

It was created to make routine server updates safer by verifying the current state of the host and applications, backing up persistent application data, creating a system snapshot, applying updates, and validating the server afterwards.

The project is primarily designed for Debian-based servers using `systemd`, `APT`, `Timeshift` and rootless `Podman`.

---

## Project Information

- **Project:** Safe Update
- **Version:** 1.0-test
- **Status:** Experimental / Testing
- **Created:** August 12, 2026
- **Author:** Wojciech Surowiecki
- **Alias:** Bolo
- **GitHub:** `SuraSurow`
- **License:** GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`)

> Safe Update 1.0-test is an early test release.  
> It has been tested on a Debian 13 server, but it should be carefully validated before being enabled on any new production system.

---

## Purpose

Updating a production server is not only about running:

```bash
apt upgrade
```

A safe update process should answer several questions first:

- Is the server healthy before the update?
- Are all important application files included in backups?
- Are database dumps valid?
- Are persistent container mounts still consistent with the configuration?
- Is there a system snapshot that can be restored?
- Are applications still working after the update?
- Can the previous system state be restored if something fails?

Safe Update automates most of this process.

---

## Features

Safe Update currently provides:

- APT update detection
- pre-update host health checks
- pre-update application health checks
- persistent storage inventory validation
- PostgreSQL database backups
- filesystem directory backups
- rootless Podman volume backups
- SHA256 checksum generation and validation
- `.tar.gz` archive verification
- PostgreSQL dump verification
- Timeshift system snapshots
- APT system updates
- post-update health checks
- configurable backup retention
- configurable Timeshift snapshot retention
- manual rollback to a pre-update snapshot
- systemd service integration
- systemd timer for automatic scheduled execution
- modular per-service configuration

If no updates are available, Safe Update exits without creating unnecessary backups or snapshots.

---

## Update Workflow

```text
Check for available updates
            |
            v
      Updates found?
       /          \
     NO            YES
     |              |
     v              v
   STOP      Pre-update health check
                    |
                    v
             Storage inventory
                    |
                    v
              Data backup
                    |
                    v
            Backup verification
                    |
                    v
             Timeshift snapshot
                    |
                    v
               APT update
                    |
                    v
            Post-update health
                    |
              +-----+-----+
              |           |
            PASS         FAIL
              |           |
              v           v
          Retention    Preserve snapshot
              |           |
              v           v
            FINISH    Manual rollback
```

Automatic operating-system rollback is intentionally not enabled by default.

---

## Project Structure

```text
safe-update/
├── safe-update
├── install.sh
├── uninstall.sh
├── LICENSE
├── README.md
├── README_PL.md
├── .gitignore
│
├── lib/
│   ├── backup.sh
│   ├── config.sh
│   ├── health.sh
│   ├── inventory.sh
│   ├── report.sh
│   ├── retention.sh
│   ├── rollback.sh
│   ├── snapshot.sh
│   ├── update-check.sh
│   ├── update.sh
│   └── verify.sh
│
├── config/
│   ├── safe-update.conf.example
│   └── services/
│       └── example.conf.example
│
└── systemd/
    ├── safe-update.service
    └── safe-update.timer
```

---

## Requirements

Safe Update is currently designed around:

- Debian
- systemd
- APT
- Timeshift
- rsync
- curl
- tar
- SHA256 tools
- root privileges

Optional application integration currently focuses on:

- rootless Podman
- PostgreSQL

---

## Installation

Clone the repository:

```bash
git clone <repository-url>
cd safe-update
```

Run the installer:

```bash
sudo ./install.sh
```

The installer places the program in:

```text
/opt/safe-update
```

Configuration is stored in:

```text
/etc/safe-update
```

Runtime data and backups are stored in:

```text
/var/lib/safe-update
```

Logs may be stored in:

```text
/var/log/safe-update
```

systemd units are installed in:

```text
/etc/systemd/system/
```

The installer does **not** automatically enable scheduled updates.

---

## Global Configuration

Main configuration:

```text
/etc/safe-update/safe-update.conf
```

Example:

```bash
TIMESHIFT_DEVICE="/dev/vda4"

BACKUP_RETENTION=7
SNAPSHOT_RETENTION=5

ROOT_DISK_MAX_PERCENT=90
MIN_AVAILABLE_MEMORY_MB=256
```

### Finding the root device

Check the device containing `/`:

```bash
findmnt -no SOURCE /
```

Example:

```text
/dev/vda4
```

Configure the correct device before using snapshot or rollback functionality.

---

## Service Configuration

Each protected application has its own configuration file:

```text
/etc/safe-update/services/
```

Example:

```text
/etc/safe-update/services/example.conf
```

Example configuration:

```bash
SERVICE_NAME="example"
SERVICE_USER="svc-example"

DB_TYPE="postgres"

DB_CONTAINER="example-postgres"
DB_NAME="example"
DB_USER="example"

BACKUP_PATHS=(
  "/home/svc-example/data"
)

BACKUP_VOLUMES=(
  "example-data"
)

EXPECTED_MOUNTS=(
  "example-postgres|volume|/var/lib/postgresql/data"
  "example-app|volume|/usr/src/example/data"
)

HEALTH_URL="https://example.com/"
```

---

## Persistent Storage Inventory

Safe Update compares configured persistent mounts against mounts currently used by running containers.

If:

- a new persistent mount appears,
- an expected mount disappears,
- or the storage layout changes,

the update pipeline stops.

This is intended to prevent application data from being silently excluded from backups.

---

## Database Backups

Current dedicated database support:

```text
PostgreSQL
```

PostgreSQL dumps are created with:

```bash
pg_dump -Fc
```

The resulting dump is checked using PostgreSQL restore tooling.

For services without a database:

```bash
DB_TYPE="none"
```

---

## Health Checks

### Host checks

Safe Update can verify:

- failed systemd units
- nginx configuration
- nginx service state
- nftables ruleset availability
- root filesystem usage
- available RAM

Example limits:

```bash
ROOT_DISK_MAX_PERCENT=90
MIN_AVAILABLE_MEMORY_MB=256
```

### Application checks

Per-service checks can include:

- service account existence
- rootless Podman availability
- container state
- PostgreSQL `SELECT 1`
- HTTP/HTTPS endpoint availability

These are smoke tests, not full end-to-end application tests.

---

## Commands

### Check for updates

```bash
sudo /opt/safe-update/safe-update check
```

### Create and verify application backups

```bash
sudo /opt/safe-update/safe-update backup
```

### Run the complete update pipeline

```bash
sudo /opt/safe-update/safe-update run
```

### Roll back

```bash
sudo /opt/safe-update/safe-update rollback SNAPSHOT_NAME
```

Example:

```bash
sudo /opt/safe-update/safe-update rollback 2026-08-12_17-08-12
```

Timeshift may reboot the machine during the restore process.

---

## systemd Service

Run Safe Update through systemd:

```bash
sudo systemctl start safe-update.service
```

Check status:

```bash
systemctl status safe-update.service --no-pager
```

View logs:

```bash
sudo journalctl -u safe-update.service
```

---

## Automatic Execution

Enable the timer:

```bash
sudo systemctl enable --now safe-update.timer
```

Check it:

```bash
systemctl status safe-update.timer --no-pager
```

or:

```bash
systemctl list-timers safe-update.timer --no-pager
```

The default configuration runs Safe Update once per day with a randomized delay.

Automatic rollback is currently not enabled.

---

## Backup Retention

Application backup retention is configured using:

```bash
BACKUP_RETENTION=7
```

Only the configured number of newest backups is retained.

---

## Snapshot Retention

Safe Update Timeshift retention is configured using:

```bash
SNAPSHOT_RETENTION=5
```

The retention mechanism is intended to remove only Safe Update pre-update snapshots.

Other Timeshift snapshots should not be removed by this mechanism.

---

## Rollback

Before installing updates, Safe Update creates a Timeshift snapshot.

If the post-update health check fails:

- the run returns an error,
- the pre-update snapshot is preserved,
- the snapshot name is displayed,
- the administrator can perform a manual rollback.

Example:

```bash
sudo /opt/safe-update/safe-update rollback SNAPSHOT_NAME
```

Manual rollback is intentional in version `1.0-test`.

A temporary application failure should not automatically trigger a full operating system restore without administrator review.

---

## Logs and Reports

systemd logs:

```bash
sudo journalctl -u safe-update.service
```

Application backups:

```text
/var/lib/safe-update/backups/
```

Update runs:

```text
/var/lib/safe-update/update-check/
```

Backup directories may contain:

```text
backup.log
report.md
SHA256SUMS
```

---

## Security Model

Safe Update runs as `root`.

This is necessary because the program needs access to:

- APT
- Timeshift
- protected system files
- systemd
- firewall state
- system-wide backup destinations
- multiple rootless Podman service accounts

Recommended permissions:

```text
/opt/safe-update                   root:root 700
/etc/safe-update                   root:root 700
/etc/safe-update/safe-update.conf  root:root 600
/etc/safe-update/services/*.conf   root:root 600
/var/lib/safe-update               root:root 700
```

Service accounts should follow the principle of least privilege.

Safe Update should not require application service users to receive `sudo` access.

---

## Uninstallation

Run:

```bash
sudo ./uninstall.sh
```

The uninstaller removes the program and systemd units.

For safety, it intentionally preserves:

```text
/etc/safe-update
/var/lib/safe-update
/var/log/safe-update
```

This prevents accidental deletion of configuration and backup data.

---

## Recommended Deployment Procedure

Before enabling automatic execution on a new server:

1. Install Safe Update.
2. Configure the global settings.
3. Add all protected applications.
4. Verify persistent storage inventory.
5. Run a manual backup.
6. Verify database and filesystem backups.
7. Run health checks.
8. Create a Timeshift snapshot.
9. Perform a controlled rollback test.
10. Run the complete update process manually.
11. Confirm that applications remain operational.
12. Enable `safe-update.timer`.

Do not assume rollback compatibility on a new server without testing it first.

---

## Current Limitations

Version `1.0-test` currently has the following limitations:

- tested primarily on Debian 13
- automatic rollback is disabled
- dedicated database dump support is currently limited to PostgreSQL
- container integration focuses on rootless Podman
- health checks are smoke tests
- Timeshift behavior may depend on disk and boot partition layout
- the first real update should be supervised on every new deployment
- the project is still considered experimental

---

## Tested Reference Environment

Initial development and testing was performed on:

```text
Debian 13
systemd
APT
Timeshift RSYNC snapshots
rootless Podman
PostgreSQL containers
nginx
nftables
```

The rollback mechanism was tested against a system with separate root, `/boot`, and `/boot/efi` filesystems.

This does not guarantee identical behavior on another storage layout.

---

## Version

### 1.0-test — 2026-08-12

Initial public/test version.

Implemented:

- modular configuration
- APT update detection
- persistent storage inventory
- application backups
- PostgreSQL dumps
- backup verification
- Timeshift snapshots
- host and application health checks
- update pipeline
- manual rollback
- backup retention
- snapshot retention
- systemd service
- automatic systemd timer
- portable installation structure

---

## Author

**Wojciech Surowiecki**

Also known as:

**Bolo**

GitHub:

**SuraSurow**

Project created on **August 12, 2026**.

---

## License

Copyright © 2026 Wojciech Surowiecki

This project is licensed under the **GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later)**.

You may use, study, modify and redistribute this software under the terms of the GNU Affero General Public License.

If you distribute a modified version or use a modified AGPL-covered version in a way that triggers the network-source provisions of the license, the corresponding source code must be made available under the applicable AGPL terms.

See the `LICENSE` file for the complete license text.

Safe Update is provided **without warranty**, to the extent permitted by applicable law.
