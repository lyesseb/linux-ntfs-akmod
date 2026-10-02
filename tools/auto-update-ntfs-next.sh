#!/usr/bin/bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPDATE_SCRIPT="$PROJECT/tools/update-ntfs-next.sh"
SPEC_FILE="$PROJECT/SPECS/linux-ntfs-kmod.spec"
COMMIT_FILE="$PROJECT/documentation/ntfs-next-commit.txt"
REQUEST_DIR="/run/linux-ntfs-akmod"
REQUESTING_USER="$(/usr/bin/id -un)"; REQUESTING_UID="$(/usr/bin/id -u)"; REQUESTING_GID="$(/usr/bin/id -g)"
die(){ echo "ERREUR : $*" >&2; exit 1; }
for c in git rpm rpmspec rpmbuild systemctl mktemp chmod chown mv; do command -v "/usr/bin/$c" >/dev/null 2>&1 || die "$c introuvable"; done
SHA_UPSTREAM="$(/usr/bin/git ls-remote https://github.com/namjaejeon/linux-ntfs.git refs/heads/ntfs-next | /usr/bin/awk 'NR==1{print $1;exit}')"
[[ "$SHA_UPSTREAM" =~ ^[0-9a-f]{40}$ ]] || die "SHA upstream invalide"
SHA_INSTALLED=""
if /usr/bin/rpm -q akmod-linux-ntfs >/dev/null 2>&1; then SHA_INSTALLED="$(/usr/bin/rpm -q --changelog akmod-linux-ntfs 2>/dev/null | /usr/bin/grep -m1 -Eo 'Update to ntfs-next commit [0-9a-f]{40}' | /usr/bin/grep -Eo '[0-9a-f]{40}' | /usr/bin/head -n1 || true)"; fi
[[ "$SHA_UPSTREAM" == "$SHA_INSTALLED" ]] && exit 0
/usr/bin/env bash "$UPDATE_SCRIPT"
COMMIT_FILE_SHA="$(/usr/bin/head -n1 "$COMMIT_FILE" | /usr/bin/tr -d '[:space:]')"
[[ "$COMMIT_FILE_SHA" == "$SHA_UPSTREAM" ]] || die "commit documenté différent du SHA upstream"
AKMOD_METADATA="$(/usr/bin/rpmspec -q --qf '%{NAME}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' "$SPEC_FILE" | /usr/bin/awk -F '\t' '$1=="akmod-linux-ntfs"{print;exit}')"
[[ -n "$AKMOD_METADATA" ]] || die "sous-paquet akmod-linux-ntfs introuvable"
IFS=$'\t' read -r AKMOD_NAME AKMOD_VERSION AKMOD_RELEASE AKMOD_ARCH <<< "$AKMOD_METADATA"
[[ "$AKMOD_NAME" == akmod-linux-ntfs ]] || die "nom de sous-paquet inattendu"
[[ "$AKMOD_ARCH" == "$(/usr/bin/rpm --eval '%{_arch}')" ]] || die "architecture akmod inattendue"
RPMBUILD_TOPDIR="$HOME/rpmbuild"; /usr/bin/rpmbuild -ba "$SPEC_FILE" --define "_topdir $RPMBUILD_TOPDIR"
RPM_DIR="$RPMBUILD_TOPDIR/RPMS/$AKMOD_ARCH"; AKMOD_VERSION_RELEASE="$AKMOD_VERSION-$AKMOD_RELEASE"
AKMOD_RPM="$RPM_DIR/akmod-linux-ntfs-$AKMOD_VERSION_RELEASE.$AKMOD_ARCH.rpm"; KMOD_RPM="$RPM_DIR/kmod-linux-ntfs-$AKMOD_VERSION_RELEASE.$AKMOD_ARCH.rpm"; COMMON_RPM="$RPM_DIR/linux-ntfs-kmod-common-$AKMOD_VERSION_RELEASE.$AKMOD_ARCH.rpm"
for f in "$AKMOD_RPM" "$KMOD_RPM" "$COMMON_RPM"; do [[ -f "$f" && ! -L "$f" ]] || die "RPM attendu absent/invalide: $f"; [[ "$(/usr/bin/stat -c '%u' "$f")" -eq "$REQUESTING_UID" ]] || die "RPM non possédé: $f"; done
[[ "$(/usr/bin/rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$AKMOD_RPM")" == "akmod-linux-ntfs-$AKMOD_VERSION_RELEASE.$AKMOD_ARCH" ]] || die "AKMOD incohérent"
CANDIDATE_SHA="$(/usr/bin/rpm -qp --changelog "$AKMOD_RPM" 2>/dev/null | /usr/bin/grep -m1 -Eo 'Update to ntfs-next commit [0-9a-f]{40}' | /usr/bin/grep -Eo '[0-9a-f]{40}' | /usr/bin/head -n1 || true)"
[[ "$CANDIDATE_SHA" == "$SHA_UPSTREAM" ]] || die "SHA du RPM différent du SHA upstream"
[[ "$(/usr/bin/rpm -qp --qf '%{NAME}' "$KMOD_RPM")" == kmod-linux-ntfs ]] || die "KMOD incohérent"
[[ "$(/usr/bin/rpm -qp --qf '%{NAME}' "$COMMON_RPM")" == linux-ntfs-kmod-common ]] || die "common incohérent"
mkdir -p "$REQUEST_DIR"; REQUEST_FILE="$REQUEST_DIR/install-$REQUESTING_USER.env"; REQUEST_TMP="$(/usr/bin/mktemp "$REQUEST_DIR/.install-$REQUESTING_USER.XXXXXX")"
trap '/usr/bin/rm -f -- "$REQUEST_TMP"' EXIT
/usr/bin/chmod 600 "$REQUEST_TMP"; /usr/bin/chown "$REQUESTING_UID:$REQUESTING_GID" "$REQUEST_TMP"
{ printf 'TARGET_AKMOD_RPM=%s\n' "$AKMOD_RPM"; printf 'EXPECTED_COMMIT=%s\n' "$SHA_UPSTREAM"; } > "$REQUEST_TMP"
/usr/bin/mv -f "$REQUEST_TMP" "$REQUEST_FILE"; trap - EXIT
/usr/bin/systemctl start "linux-ntfs-akmod-install@$REQUESTING_USER.service"
