#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

SERVICE_TEMPLATE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.service.in"
TIMER_SOURCE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.timer"

AKMOD_SERVICE_TEMPLATE="$PROJECT_DIR/tools/systemd/linux-ntfs-akmod-install@.service.in"
AKMOD_HELPER="$PROJECT_DIR/tools/linux-ntfs-akmod-install"
POLKIT_SOURCE="$PROJECT_DIR/tools/polkit/49-linux-ntfs-akmod.rules"
DEPENDENCIES_INSTALLER="$PROJECT_DIR/tools/install-dependencies.sh"
DRACUT_CONFIG="$PROJECT_DIR/tools/dracut/90-linux-ntfs.conf"

USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

SERVICE_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.service"
TIMER_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.timer"

SYSTEM_SERVICE_DEST="/etc/systemd/system/linux-ntfs-akmod-install@.service"
SYSTEM_HELPER_DEST="/usr/libexec/linux-ntfs-akmod-install"
POLKIT_RULE_DEST="/etc/polkit-1/rules.d/49-linux-ntfs-akmod.rules"
DRACUT_CONFIG_DEST="/etc/dracut.conf.d/90-linux-ntfs.conf"

if [[ "$(id -u)" -eq 0 ]]; then
    printf '%s\n'         "ERREUR : cet installateur doit être exécuté par l'utilisateur cible, sans sudo." >&2
    printf '%s\n'         "Les opérations nécessitant root utilisent sudo automatiquement." >&2
    exit 1
fi

USER_NAME="$(id -un)"

printf '%s\n' '=== INSTALLATION LINUX-NTFS ==='
printf 'Projet      : %s\n' "$PROJECT_DIR"
printf 'Utilisateur : %s\n' "$USER_NAME"

for file in \
    "$SERVICE_TEMPLATE" \
    "$TIMER_SOURCE" \
    "$AKMOD_SERVICE_TEMPLATE" \
    "$AKMOD_HELPER" \
    "$POLKIT_SOURCE" \
    "$DEPENDENCIES_INSTALLER" \
    "$DRACUT_CONFIG"
do
    if [[ ! -f "$file" ]]; then
        printf 'ERREUR : fichier introuvable : %s\n' "$file" >&2
        exit 1
    fi
done

if [[ ! -x "$PROJECT_DIR/tools/auto-update-ntfs-next.sh" ]]; then
    printf 'ERREUR : orchestrateur introuvable ou non exécutable.\n' >&2
    exit 1
fi

if [[ ! -x "$AKMOD_HELPER" ]]; then
    printf 'ERREUR : helper AKMOD non exécutable.\n' >&2
    exit 1
fi

if [[ ! -x "$DEPENDENCIES_INSTALLER" ]]; then
    printf 'ERREUR : installateur de dépendances non exécutable.\n' >&2
    exit 1
fi

printf '\n%s\n' '=== INSTALLATION DES DEPENDANCES ==='

"$DEPENDENCIES_INSTALLER"

printf '\n%s\n' '=== INSTALLATION SERVICE SYSTÈME ==='

sudo /usr/bin/install -D -m 755 \
    "$AKMOD_HELPER" \
    "$SYSTEM_HELPER_DEST"

sudo /usr/bin/sed \
    "s|@HELPER_PATH@|$SYSTEM_HELPER_DEST|g" \
    "$AKMOD_SERVICE_TEMPLATE" |
    sudo /usr/bin/tee "$SYSTEM_SERVICE_DEST" >/dev/null

sudo /usr/bin/install -D -m 644 \
    "$POLKIT_SOURCE" \
    "$POLKIT_RULE_DEST"

sudo /usr/bin/install -D -m 644 \
    "$DRACUT_CONFIG" \
    "$DRACUT_CONFIG_DEST"

printf '%s\n' '✓ Helper root installé.'
printf '%s\n' '✓ Service systemd installé.'
printf '%s\n' '✓ Règle Polkit installée.'
printf '%s\n' '✓ Configuration Dracut installée.'

printf '\n%s\n' '=== INSTALLATION SYSTEMD UTILISATEUR ==='

/usr/bin/mkdir -p "$USER_SYSTEMD_DIR"

/usr/bin/sed \
    "s|@PROJECT_DIR@|$PROJECT_DIR|g" \
    "$SERVICE_TEMPLATE" \
    > "$SERVICE_DEST"

/usr/bin/cp \
    "$TIMER_SOURCE" \
    "$TIMER_DEST"

/usr/bin/chmod 644 \
    "$SERVICE_DEST" \
    "$TIMER_DEST"

sudo /usr/bin/systemctl daemon-reload
sudo /usr/bin/systemctl restart polkit.service

printf '\n%s\n' '=== RECONSTRUCTION INITRAMFS ==='

sudo /usr/bin/dracut --regenerate-all --force

/usr/bin/systemctl --user daemon-reload
/usr/bin/systemctl --user enable --now \
    linux-ntfs-next-update.timer

printf '\n%s\n' '=== INSTALLATION TERMINÉE ==='
printf 'Service système : %s\n' "$SYSTEM_SERVICE_DEST"
printf 'Helper root      : %s\n' "$SYSTEM_HELPER_DEST"
printf 'Polkit           : %s\n' "$POLKIT_RULE_DEST"
printf 'Dracut           : %s\n' "$DRACUT_CONFIG_DEST"
printf 'Service user     : %s\n' "$SERVICE_DEST"
printf 'Timer user       : %s\n' "$TIMER_DEST"

/usr/bin/systemctl --user status \
    linux-ntfs-next-update.timer \
    --no-pager

printf '\n%s\n' '=== PROCHAINES EXÉCUTIONS ==='

/usr/bin/systemctl --user list-timers \
    linux-ntfs-next-update.timer \
    --no-pager
