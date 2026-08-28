# linux-ntfs-akmod

Fedora RPM/akmod packaging and maintenance automation for the experimental **linux-ntfs** kernel driver from Namjae Jeon, using the `ntfs-next` development branch.

> **Status:** experimental project. The package tracks the upstream `ntfs-next` development branch and is intended for testing and use on Fedora 44 systems. It is independent of the desktop environment and integrates with the standard Fedora storage stack (`udisks2`).

## What this project provides

- `linux-ntfs` built as Fedora RPM packages with **akmod** integration.
- Automatic rebuild of the module for installed Fedora kernels through **akmods**.
- Automatic monitoring of the upstream `ntfs-next` branch.
- Automatic source archive and SPEC maintenance when upstream changes.
- A user systemd timer that performs the periodic upstream check.
- A controlled root installation path using systemd and Polkit instead of direct privileged operations from the user service.
- Native NTFS mounting through the `ntfs` kernel filesystem driver.

The project is designed so that a normal user does not need to manually compile `ntfs.ko` after every kernel update.

## Current reference

| Item | Current value |
| --- | --- |
| Fedora target | Fedora 44 |
| RPM version | `20260807` |
| RPM release | `14.fc44` |
| Upstream branch | `ntfs-next` |
| Upstream commit | `4e41ce6f7a7711299e12dcb9c77533a7ab273913` |
| Upstream subject | `ntfs: compute bi_sector in 512-byte units` |
| Project commit | `1e8152e` |

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

## Package layout

A successful build produces the common, generic KMOD and AKMOD packages, for example:

```text
linux-ntfs-kmod-common-20260807-14.fc44.x86_64.rpm
kmod-linux-ntfs-20260807-14.fc44.x86_64.rpm
akmod-linux-ntfs-20260807-14.fc44.x86_64.rpm
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

## Validation multi-machines

The project has now been validated on four Fedora machines. The ASUS
validation recorded on 2026-08-28 is a complete clean-installation,
reboot and functional-mount validation on an ASUS PRIME H310M-K R2.0
with Fedora 44 kernel `7.1.10-200.fc44.x86_64`.

The ASUS scenario included:

- complete project uninstallation;
- confirmation that the Linux-NTFS packages, module and user timer were absent;
- clean reinstallation through `tools/install-systemd-user.sh`;
- successful AKMOD RPM build and installation through the systemd root helper;
- reconstruction of the current kernel initramfs by the corrected installation helper;
- reboot and automatic loading of `ntfs.ko`;
- absence of `ntfs-3g`;
- enabled and waiting user maintenance timer;
- successful Dolphin/UDisks functional test with an actual `ntfs` filesystem mount, not `fuseblk`.

See [`documentation/VALIDATION-MACHINES.txt`](documentation/VALIDATION-MACHINES.txt) for the detailed ASUS validation record.

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
