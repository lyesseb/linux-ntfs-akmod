#!/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT/tools/update-ntfs-next.sh"
LOCK="/tmp/auto-update-ntfs-next.lock"

cleanup() {
    /usr/bin/rm -f "$LOCK"
}

if ! (set -o noclobber; /usr/bin/printf '%s\n' "$$" > "$LOCK") 2>/dev/null; then
    echo "Une autre exécution de auto-update-ntfs-next.sh est déjà en cours."
    exit 0
fi

trap cleanup EXIT

echo "============================================================"
echo "       linux-ntfs / automatic upstream update"
echo "============================================================"
echo
echo "Projet : $PROJECT"
echo

printf '%s\n' '=== ÉTAT AVANT MISE À JOUR ==='

BEFORE_COMMIT=$(/usr/bin/head -n 1 \
    "$PROJECT/documentation/ntfs-next-commit.txt")

BEFORE_RELEASE=$(/usr/bin/rpmspec -q --qf '%{RELEASE}\n' \
    "$PROJECT/SPECS/linux-ntfs-kmod.spec" |
    /usr/bin/head -n 1)

printf 'Commit : %s\n' "$BEFORE_COMMIT"
printf 'Release : %s\n' "$BEFORE_RELEASE"

printf '\n%s\n' '=== EXÉCUTION DU SCRIPT UPSTREAM ==='

/usr/bin/bash "$SCRIPT"

AFTER_COMMIT=$(/usr/bin/head -n 1 \
    "$PROJECT/documentation/ntfs-next-commit.txt")

AFTER_RELEASE=$(/usr/bin/rpmspec -q --qf '%{RELEASE}\n' \
    "$PROJECT/SPECS/linux-ntfs-kmod.spec" |
    /usr/bin/head -n 1)

printf '\n%s\n' '=== ÉTAT APRÈS MISE À JOUR ==='
printf 'Commit : %s\n' "$AFTER_COMMIT"
printf 'Release : %s\n' "$AFTER_RELEASE"

BUILD_REASON=""

if [[ "${FORCE_BUILD:-0}" == "1" ]]; then
    BUILD_REASON="force"
elif [[ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]]; then
    BUILD_REASON="upstream"
else
    echo
    echo "✓ Aucun nouveau commit upstream."

    EXPECTED_COMMIT="$AFTER_COMMIT"
    INSTALLED_COMMIT=""

    if /usr/bin/rpm -q akmod-linux-ntfs >/dev/null 2>&1; then
        INSTALLED_COMMIT="$(
            /usr/bin/rpm -q --changelog akmod-linux-ntfs 2>/dev/null |
            /usr/bin/grep -oE '[0-9a-f]{40}' |
            /usr/bin/head -n 1 ||
            true
        )"
    fi

    echo "Commit attendu : $EXPECTED_COMMIT"
    echo "Commit AKMOD   : ${INSTALLED_COMMIT:-aucun}"

    CURRENT_KERNEL=$(/usr/bin/uname -r)

    if [[ "$INSTALLED_COMMIT" == "$EXPECTED_COMMIT" ]] &&
       /usr/bin/modinfo -k "$CURRENT_KERNEL" ntfs >/dev/null 2>&1; then
        echo "✓ AKMOD et module ntfs correspondent au commit suivi."
        echo "✓ Aucun build RPM nécessaire."
        exit 0
    fi

    BUILD_REASON="installed-mismatch"
fi

echo

case "$BUILD_REASON" in
    force)
        echo "⚠ FORCE_BUILD=1 : branche de construction forcée pour test."
        ;;
    upstream)
        echo "⚠ Nouveau commit upstream détecté."
        echo "  Ancien : $BEFORE_COMMIT"
        echo "  Nouveau : $AFTER_COMMIT"
        ;;
    installed-mismatch)
        echo "⚠ Le pilote installé ne correspond pas au commit suivi."
        ;;
    *)
        echo "ERREUR : raison de construction inconnue."
        exit 1
        ;;
esac

echo "La branche de construction va maintenant être exécutée."

# Supprime un SRPM existant portant exactement la même référence.
remove_existing_srpm() {
    local srpm_dir="$1"
    local srpm_name="$2"
    local srpm_path="$srpm_dir/$srpm_name"

    if [[ -f "$srpm_path" ]]; then
        echo "⚠ SRPM existant détecté : $srpm_path"
        echo "→ Suppression avant reconstruction."
        /usr/bin/rm -f -- "$srpm_path"
    fi
}

RPMBUILD_TOPDIR="$HOME/rpmbuild"
RPMBUILD_SPEC="$RPMBUILD_TOPDIR/SPECS/linux-ntfs-kmod.spec"

/usr/bin/mkdir -p \
    "$RPMBUILD_TOPDIR/BUILD" \
    "$RPMBUILD_TOPDIR/BUILDROOT" \
    "$RPMBUILD_TOPDIR/RPMS" \
    "$RPMBUILD_TOPDIR/SOURCES" \
    "$RPMBUILD_TOPDIR/SPECS" \
    "$RPMBUILD_TOPDIR/SRPMS"

SPEC_EXPANDED=$(
    /usr/bin/rpmspec -P "$PROJECT/SPECS/linux-ntfs-kmod.spec"
)

SOURCE_NAME=$(
    /usr/bin/printf '%s\n' "$SPEC_EXPANDED" |
    /usr/bin/awk '$1 == "Source0:" {print $2; exit}'
)

if [[ -z "$SOURCE_NAME" ]]; then
    echo "ERREUR : Source0 introuvable dans le SPEC."
    exit 1
fi

echo "=== SYNCHRONISATION RPMBUILD ==="

echo "SPEC : $RPMBUILD_SPEC"

/usr/bin/cp -v \
    "$PROJECT/SPECS/linux-ntfs-kmod.spec" \
    "$RPMBUILD_SPEC"

echo
echo "=== SYNCHRONISATION SOURCES / PATCHES ==="

mapfile -t RPM_INPUTS < <(
    printf '%s\\n' "$SPEC_EXPANDED" |
    /usr/bin/awk '
        $1 ~ /^Source[0-9]*:$/ || $1 ~ /^Patch[0-9]*:$/ {
            print $2
        }
    '
)

if [[ "${#RPM_INPUTS[@]}" -eq 0 ]]; then
    echo "ERREUR : aucun Source/Patch trouvé dans le SPEC."
    exit 1
fi

for RPM_INPUT in "${RPM_INPUTS[@]}"; do
    INPUT_FILE="$PROJECT/SOURCES/$RPM_INPUT"
    RPMBUILD_INPUT="$RPMBUILD_TOPDIR/SOURCES/$RPM_INPUT"

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "ERREUR : fichier Source/Patch introuvable :"
        echo "$INPUT_FILE"
        exit 1
    fi

    echo "SOURCE/PATCH : $INPUT_FILE"
    echo "              -> $RPMBUILD_INPUT"

    /usr/bin/cp -v         "$INPUT_FILE"         "$RPMBUILD_INPUT"
done

echo
echo "=== IDENTIFICATION DU RPM AKMOD ATTENDU ==="

AKMOD_NAME=$(
    /usr/bin/rpmspec -q --qf '%{NAME}\n' \
        "$RPMBUILD_SPEC" |
    /usr/bin/grep '^akmod-linux-ntfs$' |
    /usr/bin/head -n 1
)

AKMOD_VERSION=$(
    /usr/bin/rpmspec -q --qf '%{VERSION}\n' \
        "$RPMBUILD_SPEC" |
    /usr/bin/head -n 1
)

AKMOD_RELEASE=$(
    /usr/bin/rpmspec -q --qf '%{RELEASE}\n' \
        "$RPMBUILD_SPEC" |
    /usr/bin/head -n 1
)

AKMOD_ARCH=$(
    /usr/bin/rpmspec -q --qf '%{ARCH}\n' \
        "$RPMBUILD_SPEC" |
    /usr/bin/head -n 1
)

AKMOD_RPM="$RPMBUILD_TOPDIR/RPMS/$AKMOD_ARCH/$AKMOD_NAME-$AKMOD_VERSION-$AKMOD_RELEASE.$AKMOD_ARCH.rpm"

SRPM_NAME="${AKMOD_NAME/akmod-linux-ntfs/linux-ntfs-kmod}-${AKMOD_VERSION}-${AKMOD_RELEASE}.src.rpm"

printf 'Nom      : %s\n' "$AKMOD_NAME"
printf 'Version  : %s\n' "$AKMOD_VERSION"
printf 'Release  : %s\n' "$AKMOD_RELEASE"
printf 'Arch     : %s\n' "$AKMOD_ARCH"
printf 'RPM      : %s\n' "$AKMOD_RPM"
echo
echo "=== NETTOYAGE SRPM DE MÊME RÉFÉRENCE ==="

remove_existing_srpm     "$RPMBUILD_TOPDIR/SRPMS"     "$SRPM_NAME"

echo "SRPM cible : $RPMBUILD_TOPDIR/SRPMS/$SRPM_NAME"

echo
echo "=== RPMBUILD -ba ==="

/usr/bin/rpmbuild -ba \
    "$RPMBUILD_SPEC" \
    --define "_topdir $RPMBUILD_TOPDIR"

echo
echo "✓ rpmbuild -ba terminé."

echo
echo "=== VÉRIFICATION DU RPM AKMOD ==="

if [[ ! -f "$AKMOD_RPM" ]]; then
    echo "ERREUR : le RPM AKMOD attendu n'existe pas :"
    echo "$AKMOD_RPM"
    exit 1
fi

/usr/bin/ls -lh "$AKMOD_RPM"

echo
echo "============================================================"
echo "RPM AKMOD CONSTRUIT"
echo "============================================================"
echo
echo "RPM : $AKMOD_RPM"
echo
echo "✓ Le RPM akmod a été construit avec succès."

REQUESTING_USER=$(/usr/bin/id -un)

echo
echo "=== INSTALLATION DU RPM AKMOD ==="
echo "Utilisateur demandeur : $REQUESTING_USER"
echo "Service : linux-ntfs-akmod-install@${REQUESTING_USER}.service"

if ! /usr/bin/systemctl start "linux-ntfs-akmod-install@${REQUESTING_USER}.service"
then
    echo "ERREUR : impossible de lancer le service d'installation AKMOD." >&2
    exit 1
fi

echo "✓ Demande d'installation transmise à systemd."
echo "✓ Aucun lancement direct de akmods effectué."
