#!/usr/bin/env bash

set -Eeuo pipefail

printf '%s\n' '=== DEPENDANCES LINUX-NTFS-AKMOD ==='

if [[ "$(id -u)" -eq 0 ]]; then
    printf '%s\n' \
        'ERREUR : cet installateur doit être exécuté par l’utilisateur cible, sans sudo.' >&2
    exit 1
fi

if ! command -v /usr/bin/dnf5 >/dev/null 2>&1; then
    printf '%s\n' 'ERREUR : dnf5 introuvable.' >&2
    exit 1
fi

FEDORA_VERSION="$(/usr/bin/rpm -E '%{fedora}')"

RPMFUSION_FREE_RELEASE="rpmfusion-free-release"
RPMFUSION_FREE_RELEASE_URL="https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"

printf '%s\n' '=== RPM FUSION FREE ==='

if /usr/bin/rpm -q "$RPMFUSION_FREE_RELEASE" >/dev/null 2>&1; then
    printf '✓ %-40s installée\n' "$RPMFUSION_FREE_RELEASE"
else
    printf '✗ %-40s manquante\n' "$RPMFUSION_FREE_RELEASE"

    printf '%s\n' '=== INSTALLATION RPM FUSION FREE ==='

    sudo /usr/bin/dnf5 -y install \
        "$RPMFUSION_FREE_RELEASE_URL"
fi

PACKAGES=(
    akmods
    kmodtool
    rpm-build
    rpmdevtools
    git
    curl
    python3
    gcc
    make
    elfutils-libelf-devel
    buildsys-build-rpmfusion
    "kernel-devel-$(uname -r)"
)

printf '%s\n' '=== DEPENDANCES MANQUANTES ==='

MISSING=()

for pkg in "${PACKAGES[@]}"; do
    if /usr/bin/rpm -q "$pkg" >/dev/null 2>&1; then
        printf '✓ %-40s installée\n' "$pkg"
    else
        printf '✗ %-40s manquante\n' "$pkg"
        MISSING+=("$pkg")
    fi
done

if (( ${#MISSING[@]} == 0 )); then
    printf '\n%s\n' \
        '✓ Toutes les dépendances principales sont déjà installées.'
    exit 0
fi

printf '\n%s\n' '=== INSTALLATION ==='
printf 'Paquets à installer :\n'

printf '  %s\n' "${MISSING[@]}"

sudo /usr/bin/dnf5 -y install "${MISSING[@]}"

printf '\n%s\n' '=== VERIFICATION ==='

if ! /usr/bin/rpm -q "$RPMFUSION_FREE_RELEASE" >/dev/null 2>&1; then
    printf '✗ %-40s MANQUANTE\n' "$RPMFUSION_FREE_RELEASE" >&2
    exit 1
fi

for pkg in "${PACKAGES[@]}"; do
    if /usr/bin/rpm -q "$pkg" >/dev/null 2>&1; then
        printf '✓ %-40s OK\n' "$pkg"
    else
        printf '✗ %-40s MANQUANTE\n' "$pkg" >&2
        exit 1
    fi
done

printf '\n%s\n' '✓ Dépendances linux-ntfs-akmod satisfaites.'
