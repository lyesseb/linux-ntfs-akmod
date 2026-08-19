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

RPMBUILD_TOPDIR="$HOME/rpmbuild"
RPMBUILD_SPEC="$RPMBUILD_TOPDIR/SPECS/linux-ntfs-kmod.spec"

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

SOURCE_FILE="$PROJECT/SOURCES/$SOURCE_NAME"
RPMBUILD_SOURCE="$RPMBUILD_TOPDIR/SOURCES/$SOURCE_NAME"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "ERREUR : archive SOURCE introuvable."
    exit 1
fi

echo "=== SYNCHRONISATION RPMBUILD ==="

echo "SPEC    : $RPMBUILD_SPEC"
echo "SOURCE  : $RPMBUILD_SOURCE"

/usr/bin/cp -v \
    "$PROJECT/SPECS/linux-ntfs-kmod.spec" \
    "$RPMBUILD_SPEC"

/usr/bin/cp -v \
    "$SOURCE_FILE" \
    "$RPMBUILD_SOURCE"

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

printf 'Nom      : %s\n' "$AKMOD_NAME"
printf 'Version  : %s\n' "$AKMOD_VERSION"
printf 'Release  : %s\n' "$AKMOD_RELEASE"
printf 'Arch     : %s\n' "$AKMOD_ARCH"
printf 'RPM      : %s\n' "$AKMOD_RPM"
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
echo "✓ Aucune installation système effectuée."
echo "✓ Aucun lancement direct de akmods effectué."
