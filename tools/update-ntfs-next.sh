```bash
#!/bin/bash

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

REPO="https://github.com/namjaejeon/linux-ntfs.git"
BRANCH="ntfs-next"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

SPEC="$PROJECT/SPECS/linux-ntfs-kmod.spec"
DOCUMENTATION="$PROJECT/documentation/ntfs-next-commit.txt"
SOURCES="$PROJECT/SOURCES"

LOCAL_TZ="$(
    /usr/bin/timedatectl show --property=Timezone --value 2>/dev/null ||
    true
)"

if [[ -z "$LOCAL_TZ" ]]; then
    LOCAL_TZ="UTC"
fi

export LOCAL_TZ

###############################################################################
# Utilitaires
###############################################################################

die()
{
    echo "ERREUR : $*" >&2
    exit 1
}

###############################################################################
# Vérifications initiales
###############################################################################

cd "$PROJECT"

for command in \
    git \
    curl \
    python3 \
    sha256sum \
    rpmspec \
    sed \
    awk \
    grep \
    head \
    tail \
    date \
    cp \
    mv \
    mkdir \
    stat \
    cmp \
    tr \
    cut \
    mktemp
do
    command -v "$command" >/dev/null 2>&1 ||
        die "commande absente : $command"
done

[[ -f "$SPEC" ]] ||
    die "SPEC absent : $SPEC"

[[ -f "$DOCUMENTATION" ]] ||
    die "documentation absente : $DOCUMENTATION"

[[ -d "$SOURCES" ]] ||
    /usr/bin/mkdir -p "$SOURCES"

###############################################################################
# Release courant
###############################################################################

SPEC_RELEASE="$(
    /usr/bin/rpmspec \
        -q \
        --qf '%{RELEASE}\n' \
        "$SPEC" |
    /usr/bin/head -n1 |
    /usr/bin/cut -d. -f1
)"

[[ "$SPEC_RELEASE" =~ ^[0-9]+$ ]] ||
    die "Release SPEC invalide : $SPEC_RELEASE"

INSTALLED_RELEASE="0"

if /usr/bin/rpm -q akmod-linux-ntfs >/dev/null 2>&1; then
    INSTALLED_RELEASE="$(
        /usr/bin/rpm \
            -q \
            --qf '%{RELEASE}\n' \
            akmod-linux-ntfs |
        /usr/bin/head -n1 |
        /usr/bin/cut -d. -f1
    )"
fi

[[ "$INSTALLED_RELEASE" =~ ^[0-9]+$ ]] ||
    die "Release installé invalide : $INSTALLED_RELEASE"

CURRENT_RELEASE="$SPEC_RELEASE"

if (( INSTALLED_RELEASE > CURRENT_RELEASE )); then
    CURRENT_RELEASE="$INSTALLED_RELEASE"
fi

echo "Release SPEC             : $SPEC_RELEASE"
echo "Release AKMOD installé   : $INSTALLED_RELEASE"
echo "Release de référence     : $CURRENT_RELEASE"

###############################################################################
# Nettoyage temporaire
###############################################################################

TMP_DIR=""

cleanup()
{
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        /usr/bin/rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

###############################################################################
# État Git
###############################################################################

/usr/bin/git diff --check ||
    die "git diff --check échoue avant modification"

###############################################################################
# Commit actuellement documenté
###############################################################################

CURRENT="$(
    /usr/bin/head -n1 "$DOCUMENTATION" |
    /usr/bin/tr -d '[:space:]'
)"

[[ "$CURRENT" =~ ^[0-9a-f]{40}$ ]] ||
    die "SHA documenté invalide : $CURRENT"

###############################################################################
# Premier changelog du SPEC
#
# Lorsque documentation == upstream, cet élément doit correspondre au même
# commit. Cela évite de construire silencieusement un SPEC incohérent.
###############################################################################

SPEC_CHANGELOG_COMMIT="$(
    /usr/bin/awk '
        /^%changelog$/ {
            in_changelog = 1
            next
        }

        in_changelog && /- Update to ntfs-next commit [0-9a-f]{40}/ {
            match($0, /[0-9a-f]{40}/)
            print substr($0, RSTART, RLENGTH)
            exit
        }
    ' "$SPEC"
)"

[[ -z "$SPEC_CHANGELOG_COMMIT" ||
   "$SPEC_CHANGELOG_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    die "SHA du premier changelog SPEC invalide : $SPEC_CHANGELOG_COMMIT"

###############################################################################
# Commit
```
