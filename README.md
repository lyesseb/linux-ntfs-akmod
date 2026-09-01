# Linux NTFS kernel driver for Fedora — AKMOD/KMOD packaging

**Fedora 44 and later** packaging, kernel-module integration and maintenance automation for the **linux-ntfs** NTFS filesystem driver developed by **Namjae Jeon**, tracking the upstream `ntfs-next` development branch.

This project packages the **Linux NTFS kernel driver** as Fedora RPM/AKMOD/KMOD packages and provides automatic kernel-module maintenance through **akmods**. It builds and maintains `ntfs.ko` for Fedora kernels and integrates with the standard Fedora storage stack (`udisks2`).

The driver is compiled as an **external kernel module** (`ntfs.ko`) from the upstream `linux-ntfs`/`ntfs-next` source. This project does not merely enable or activate an `ntfs` driver already built into the Fedora kernel.

> **Status:** experimental project for Fedora 44 and later. This repository packages and automates the upstream `linux-ntfs` driver; it is not the upstream driver repository itself. It is independent of the desktop environment and is specifically designed to provide native `ntfs` filesystem support rather than `ntfs-3g`/FUSE or the separate in-kernel `ntfs3` filesystem.

## What this project provides

- `linux-ntfs` built as Fedora RPM packages with **akmod** integration.
- Automatic rebuild of the module for installed Fedora kernels through **akmods**.
- Automatic monitoring of the upstream `ntfs-next` branch.
- Automatic source archive and SPEC maintenance when upstream changes.
- A user systemd timer that performs the periodic upstream check.
- A controlled root installation path using systemd and Polkit instead of direct privileged operations from the user service.
- Native NTFS mounting through the `ntfs` kernel filesystem driver.

The project is designed so that a normal user does not need to manually compile `ntfs.ko` after every kernel update.

## Installation

Clone the repository and run the single installation entry point as the target user:

```bash
git clone git@github.com:lyesseb/linux-ntfs-akmod.git \
    "$HOME/Developpement/linux-ntfs-akmod-dev"

cd "$HOME/Developpement/linux-ntfs-akmod-dev"

git switch ntfs-next-latest

./tools/install-systemd-user.sh
```

The installer automatically:

1. checks the required Fedora build/runtime dependencies;
2. ensures RPM Fusion Free is available;
3. removes `ntfs-3g` when it is installed, so `mount -t ntfs` is not redirected to the FUSE `ntfs-3g` helper;
4. installs the required build tools and matching `kernel-devel` for the running kernel;
5. installs the system helper, systemd template and Polkit rule;
6. installs and enables the user systemd timer.

The installer is intended to be run **without `sudo`**. It invokes `sudo` only for operations that require root privileges.

## Uninstallation

The project provides a dedicated uninstallation entry point:

```bash
cd "$HOME/Developpement/linux-ntfs-akmod-dev"
./tools/uninstall-systemd-user.sh
```

The uninstaller is intended to be run **without** **`sudo`**. It invokes `sudo` only for operations that require root privileges.

Before a real uninstallation, all NTFS volumes using the `linux-ntfs` driver must be unmounted. The uninstaller checks this automatically and stops if an `ntfs` filesystem is still mounted.

A simulation can be performed first:

```bash
./tools/uninstall-systemd-user.sh --dry-run
```

The uninstaller removes:

1. the user `linux-ntfs-next-update.timer` and its service files;
2. the system-side installation helper and systemd template;
3. the Polkit rule installed by the project;
4. the installed `akmod-linux-ntfs` package;
5. the installed `linux-ntfs-kmod-common` package;
6. all installed `kmod-linux-ntfs-*` packages.

After removal, `ntfs-3g` is restored automatically so that the system has a standard NTFS userspace handler again.

The uninstaller does **not** modify `/etc/fstab`.

After uninstallation, the project-specific automatic maintenance timer, AKMOD/KMOD packages and privileged installation path are no longer present.

## Native NTFS mounting

This project intentionally uses the upstream `linux-ntfs` filesystem driver as the `ntfs` filesystem type.

`ntfs-3g` must not intercept `-t ntfs`, because its `mount.ntfs` helper routes the request through FUSE and produces `fuseblk` mounts.

With `ntfs-3g` absent, the expected path is:

```text
Dolphin / UDisks
        ↓
      ntfs
        ↓
linux-ntfs.ko
```

NTFS volumes can then be mounted normally from Dolphin/UDisks without adding NTFS entries to `/etc/fstab`.

The validated result is an actual `ntfs` mount, not `fuseblk` and not the in-kernel `ntfs3` filesystem.

## Automatic maintenance

The main orchestrator is:

```text
tools/auto-update-ntfs-next.sh
```

It:

- checks the upstream `ntfs-next` branch;
- detects whether the tracked commit changed;
- prepares a reproducible source archive;
- updates `documentation/ntfs-next-commit.txt` and the SPEC;
- synchronizes the local `rpmbuild` tree;
- builds the expected RPMs with `rpmbuild` when required;
- identifies the expected AKMOD RPM deterministically from the SPEC;
- removes an existing SRPM carrying exactly the same version-release reference before rebuilding;
- requests installation through the systemd root helper.

The user systemd units are installed by:

```text
tools/install-systemd-user.sh
tools/systemd/linux-ntfs-next-update.service.in
tools/systemd/linux-ntfs-next-update.timer
```

The root-side installation path is implemented by:

```text
tools/linux-ntfs-akmod-install
tools/systemd/linux-ntfs-akmod-install@.service.in
tools/polkit/49-linux-ntfs-akmod.rules
```

The dependency bootstrap is:

```text
tools/install-dependencies.sh
```

### **Update robustness**

Preparation of the `ntfs-next` source archive is idempotent: an existing
stale target archive no longer prevents a new update attempt. The update
mechanism prepares the archive in a temporary location before installing it,
so a retry after a failed update can start cleanly without being blocked by
a residual artifact.

## Package layout

A successful build produces the common, generic KMOD and AKMOD packages, for example:

```text
linux-ntfs-kmod-common-<version>-<release>.<disttag>.x86_64.rpm
kmod-linux-ntfs-<version>-<release>.<disttag>.x86_64.rpm
akmod-linux-ntfs-<version>-<release>.<disttag>.x86_64.rpm
```

For a specific installed kernel, the corresponding kernel KMOD package is produced and installed by the normal Fedora akmods workflow.

## Verification

Check the current kernel and matching module:

```bash
uname -r
rpm -q "kernel-devel-$(uname -r)"
modinfo ntfs | grep -E '^(filename|description|vermagic):'
```

Check the installed packages:

```bash
rpm -qa | grep -E '^(akmod-linux-ntfs|kmod-linux-ntfs|linux-ntfs-kmod-common)-' | sort
```

Check the automatic maintenance timer:

```bash
systemctl --user status linux-ntfs-next-update.timer --no-pager
systemctl --user list-timers linux-ntfs-next-update.timer --no-pager
```

Check NTFS mounts:

```bash
findmnt -t ntfs
findmnt -t fuseblk || true
```

The expected filesystem type is `ntfs` and `fuseblk` should be absent for volumes mounted through this project.

## Validation

The project has been validated on multiple Fedora systems.

Validation records include clean installation and reinstallation scenarios,
AKMOD/KMOD installation, kernel-module loading after reboot, automatic
maintenance through the systemd user timer, and functional NTFS mounting
through Dolphin/UDisks using the `ntfs` filesystem.

See [`documentation/VALIDATION-MACHINES.txt`](documentation/VALIDATION-MACHINES.txt)
for the detailed validation records.

## Important design rules

The project intentionally keeps these responsibilities separate:

```text
upstream ntfs-next
        ↓
automatic update checker
        ↓
SPEC + source archive
        ↓
rpmbuild
        ↓
deterministic AKMOD selection
        ↓
systemd root installation helper
        ↓
akmods
        ↓
kmod-linux-ntfs for each kernel
```

Do not reintroduce:

- date-based discovery of the RPM produced by `rpmbuild`;
- permanent manual compilation of `ntfs.ko` after every kernel update;
- direct `akmods` execution from the user update service;
- NTFS mount entries in `/etc/fstab` as a workaround for graphical mounting;
- `ntfs-3g` as the handler for the `ntfs` filesystem type.

## Documentation

Detailed project documentation is available in:

- [`documentation/README.txt`](documentation/README.txt)
- [`documentation/INSTALLATION-REINSTALLATION.txt`](documentation/INSTALLATION-REINSTALLATION.txt)
- [`documentation/MAINTENANCE.txt`](documentation/MAINTENANCE.txt)
- [`documentation/ntfs-next-commit.txt`](documentation/ntfs-next-commit.txt)
- [`documentation/packages.txt`](documentation/packages.txt)
- [`documentation/VALIDATION-MACHINES.txt`](documentation/VALIDATION-MACHINES.txt)

## Upstream

Upstream project:

https://github.com/namjaejeon/linux-ntfs

This repository contains the Fedora packaging, automation and installation machinery around the upstream `ntfs-next` development branch; it is not the upstream kernel driver repository itself.
