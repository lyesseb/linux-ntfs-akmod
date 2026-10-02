#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"; PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
SERVICE_TEMPLATE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.service.in"; TIMER_SOURCE="$PROJECT_DIR/tools/systemd/linux-ntfs-next-update.timer"; AKMOD_SERVICE_TEMPLATE="$PROJECT_DIR/tools/systemd/linux-ntfs-akmod-install@.service.in"; AKMOD_HELPER="$PROJECT_DIR/tools/linux-ntfs-akmod-install"; POLKIT_SOURCE="$PROJECT_DIR/tools/polkit/49-linux-ntfs-akmod.rules"; DEPENDENCIES_INSTALLER="$PROJECT_DIR/tools/install-dependencies.sh"; DRACUT_CONFIG="$PROJECT_DIR/tools/dracut/90-linux-ntfs.conf"
USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; SERVICE_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.service"; TIMER_DEST="$USER_SYSTEMD_DIR/linux-ntfs-next-update.timer"
SYSTEM_SERVICE_DEST=/etc/systemd/system/linux-ntfs-akmod-install@.service; SYSTEM_HELPER_DEST=/usr/libexec/linux-ntfs-akmod-install; POLKIT_RULE_DEST=/etc/polkit-1/rules.d/49-linux-ntfs-akmod.rules; DRACUT_CONFIG_DEST=/etc/dracut.conf.d/90-linux-ntfs.conf
[[ "$(id -u)" -ne 0 ]] || { echo "ERREUR : exécuter comme utilisateur cible, pas root." >&2; exit 1; }
for f in "$SERVICE_TEMPLATE" "$TIMER_SOURCE" "$AKMOD_SERVICE_TEMPLATE" "$AKMOD_HELPER" "$POLKIT_SOURCE" "$DEPENDENCIES_INSTALLER" "$DRACUT_CONFIG"; do [[ -f "$f" ]] || { echo "ERREUR : fichier introuvable : $f" >&2; exit 1; }; done
[[ -x "$AKMOD_HELPER" && -x "$DEPENDENCIES_INSTALLER" && -x "$PROJECT_DIR/tools/auto-update-ntfs-next.sh" ]] || { echo "ERREUR : script requis non exécutable." >&2; exit 1; }
"$DEPENDENCIES_INSTALLER"
sudo /usr/bin/install -D -m755 "$AKMOD_HELPER" "$SYSTEM_HELPER_DEST"
sudo /usr/bin/sed "s|@HELPER_PATH@|$SYSTEM_HELPER_DEST|g" "$AKMOD_SERVICE_TEMPLATE" | sudo /usr/bin/tee "$SYSTEM_SERVICE_DEST" >/dev/null
sudo /usr/bin/install -D -m644 "$POLKIT_SOURCE" "$POLKIT_RULE_DEST"
sudo /usr/bin/install -D -m644 "$DRACUT_CONFIG" "$DRACUT_CONFIG_DEST"
sudo /usr/bin/mkdir -p /run/linux-ntfs-akmod; sudo /usr/bin/chown root:root /run/linux-ntfs-akmod; sudo /usr/bin/chmod 1777 /run/linux-ntfs-akmod
/usr/bin/mkdir -p "$USER_SYSTEMD_DIR"
/usr/bin/sed -e "s|@PROJECT_DIR@|$PROJECT_DIR|g" "$SERVICE_TEMPLATE" > "$SERVICE_DEST"
/usr/bin/cp "$TIMER_SOURCE" "$TIMER_DEST"; /usr/bin/chmod 644 "$SERVICE_DEST" "$TIMER_DEST"
sudo /usr/bin/systemctl daemon-reload; sudo /usr/bin/systemctl restart polkit.service
/usr/bin/systemctl --user daemon-reload; /usr/bin/systemctl --user enable --now linux-ntfs-next-update.timer
