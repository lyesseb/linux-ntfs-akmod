# linux-ntfs-akmod

Fedora RPM/akmod packaging and maintenance automation for the experimental **linux-ntfs** kernel driver from Namjae Jeon, using the `ntfs-next` development branch.

> **Status:** experimental project. The package tracks the upstream `ntfs-next` development branch and is intended for testing and use on Fedora 44 systems.

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
| RPM release | `5.fc44` |
| Upstream branch | `ntfs-next` |
| Upstream commit | `cbf02ac92f191fdb6c500c32072efedc1cac3a13` |
| Upstream subject | `ntfs: do not update ctime when setxattr fails` |
| Project commit | `d49f925` |

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
linux-ntfs-kmod-common-20260807-5.fc44.x86_64.rpm
kmod-linux-ntfs-20260807-5.fc44.x86_64.rpm
akmod-linux-ntfs-20260807-5.fc44.x86_64.rpm
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

## Upstream

Upstream project:

https://github.com/namjaejeon/linux-ntfs

This repository contains the Fedora packaging, automation and installation machinery around the upstream `ntfs-next` development branch; it is not the upstream kernel driver repository itself.
