#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

SERVICE_TEMPLATE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.service.in"
TIMER_SOURCE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.timer"

USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

SERVICE_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.service"
TIMER_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.timer"

printf '%s\n' '=== INSTALLATION SYSTEMD UTILISATEUR ==='
printf 'Projet : %s\n' "$PROJECT_DIR"
printf 'Destination : %s\n' "$USER_SYSTEMD_DIR"

if [[ ! -f "$SERVICE_TEMPLATE" ]]; then
    printf 'ERREUR : modèle service introuvable : %s\n' "$SERVICE_TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$TIMER_SOURCE" ]]; then
    printf 'ERREUR : timer introuvable : %s\n' "$TIMER_SOURCE" >&2
    exit 1
fi

if [[ ! -x "$PROJECT_DIR/tools/auto-update-ntfs-next.sh" ]]; then
    printf 'ERREUR : orchestrateur introuvable ou non exécutable : %s\n' \
        "$PROJECT_DIR/tools/auto-update-ntfs-next.sh" >&2
    exit 1
fi

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

/usr/bin/systemctl --user daemon-reload

/usr/bin/systemctl --user enable --now \
    linux-ntfs-next-update.timer

printf '\n%s\n' '=== INSTALLATION TERMINÉE ==='
printf '%s\n' "Service : $SERVICE_DEST"
printf '%s\n' "Timer   : $TIMER_DEST"

/usr/bin/systemctl --user status \
    linux-ntfs-next-update.timer \
    --no-pager

printf '\n%s\n' '=== PROCHAINES EXÉCUTIONS ==='

/usr/bin/systemctl --user list-timers \
    linux-ntfs-next-update.timer \
    --no-pager
