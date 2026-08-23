#!/usr/bin/env bash

set -Eeuo pipefail

DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[SIMULATION] '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

printf '%s\n' '=== DÉSINSTALLATION LINUX-NTFS ==='

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s\n' 'Mode : SIMULATION — aucune modification ne sera effectuée.'
else
    printf '%s\n' 'Mode : DÉSINSTALLATION RÉELLE.'
fi

printf '\n%s\n' '=== VERIFICATION DES MONTAGES NTFS ==='

mapfile -t NTFS_MOUNTS < <(
    findmnt -rn -t ntfs -o TARGET 2>/dev/null || true
)

if (( ${#NTFS_MOUNTS[@]} > 0 )); then
    printf '%s\n' 'Des volumes NTFS sont encore montés :'
    printf '  %s\n' "${NTFS_MOUNTS[@]}"
    printf '%s\n' 'Démontez-les avant une désinstallation réelle.'
    if [[ "$DRY_RUN" -eq 0 ]]; then
        exit 1
    fi
else
    printf '%s\n' 'Aucun volume ntfs monté.'
fi

printf '\n%s\n' '=== SYSTEMD UTILISATEUR ==='

if systemctl --user list-unit-files --no-legend 2>/dev/null |
    grep -q '^linux-ntfs-next-update\.timer'; then
    run systemctl --user disable --now linux-ntfs-next-update.timer
else
    printf '%s\n' 'Timer utilisateur absent.'
fi

USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

for file in \
    "$USER_SYSTEMD_DIR/linux-ntfs-next-update.service" \
    "$USER_SYSTEMD_DIR/linux-ntfs-next-update.timer"
do
    if [[ -e "$file" ]]; then
        run rm -f -- "$file"
    else
        printf 'Absent : %s\n' "$file"
    fi
done

printf '\n%s\n' '=== COMPOSANTS SYSTEME DU PROJET ==='

for unit in \
    /etc/systemd/system/linux-ntfs-akmod-install@.service \
    /usr/lib/systemd/system/linux-ntfs-akmod-install@.service
do
    if [[ -e "$unit" ]]; then
        run sudo rm -f -- "$unit"
    else
        printf 'Absent : %s\n' "$unit"
    fi
done

for file in \
    /usr/libexec/linux-ntfs-akmod-install \
    /usr/local/sbin/linux-ntfs-akmod-install \
    /etc/polkit-1/rules.d/49-linux-ntfs-akmod.rules
do
    if sudo test -e "$file"; then
        run sudo rm -f -- "$file"
    else
        printf 'Absent : %s\n' "$file"
    fi
done

printf '\n%s\n' '=== RECHARGEMENT SYSTEMD ==='

run sudo systemctl daemon-reload
run sudo systemctl restart polkit.service
run systemctl --user daemon-reload

printf '\n%s\n' '=== PAQUETS LINUX-NTFS ==='

mapfile -t PACKAGES < <(
    rpm -qa |
    grep -E '^(akmod-linux-ntfs|kmod-linux-ntfs|linux-ntfs-kmod-common)(-|$)' |
    sort
)

if (( ${#PACKAGES[@]} > 0 )); then
    printf '%s\n' 'Paquets détectés :'
    printf '  %s\n' "${PACKAGES[@]}"
    run sudo dnf5 -y remove "${PACKAGES[@]}"
else
    printf '%s\n' 'Aucun paquet linux-ntfs installé.'
fi

printf '\n%s\n' '=== RESTAURATION NTFS-3G ==='

if rpm -q ntfs-3g >/dev/null 2>&1; then
    printf '%s\n' 'ntfs-3g est déjà installé.'
else
    run sudo dnf5 -y install ntfs-3g
fi

printf '\n%s\n' '=== FSTAB ==='

printf '%s\n' 'Aucune modification de /etc/fstab.'
grep -nE '[[:space:]]ntfs([[:space:]]|$)|[[:space:]]ntfs-3g([[:space:]]|$)' \
    /etc/fstab || true

printf '\n%s\n' '=== DÉSINSTALLATION TERMINÉE ==='

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s\n' 'Simulation terminée : aucune modification effectuée.'
else
    printf '%s\n' 'Désinstallation terminée.'
fi
