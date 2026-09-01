#!/bin/bash

set -Eeuo pipefail

#######################################
# Configuration
#######################################

REPO="https://github.com/namjaejeon/linux-ntfs.git"
BRANCH="ntfs-next"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPEC="$PROJECT/SPECS/linux-ntfs-kmod.spec"
DOCUMENTATION="$PROJECT/documentation/ntfs-next-commit.txt"
SOURCES="$PROJECT/SOURCES"

LOCAL_TZ="$(/usr/bin/timedatectl show --property=Timezone --value 2>/dev/null || true)"

if [ -z "$LOCAL_TZ" ]; then
    LOCAL_TZ="UTC"
fi

export LOCAL_TZ

VERSION="$(/usr/bin/rpmspec -q --qf '%{VERSION}\n' "$SPEC" | /usr/bin/head -n 1)"
CURRENT_RELEASE="$(
    /usr/bin/rpmspec -q --qf '%{RELEASE}\n' "$SPEC" |
    /usr/bin/head -n 1 |
    /usr/bin/cut -d. -f1
)"

#######################################
# Nettoyage
#######################################

TMP_DIR=""

cleanup()
{
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        /usr/bin/rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

#######################################
# Vérifications
#######################################

cd "$PROJECT"

for command in \
    git \
    curl \
    python3 \
    tar \
    sha256sum \
    rpmspec \
    sed \
    awk \
    grep \
    head \
    date
do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERREUR : commande absente : $command"
        exit 1
    fi
done

if [ ! -f "$SPEC" ]; then
    echo "ERREUR : SPEC absent : $SPEC"
    exit 1
fi

if [ ! -f "$DOCUMENTATION" ]; then
    echo "ERREUR : documentation absente : $DOCUMENTATION"
    exit 1
fi

if ! [[ "$CURRENT_RELEASE" =~ ^[0-9]+$ ]]; then
    echo "ERREUR : Release RPM invalide : $CURRENT_RELEASE"
    exit 1
fi

#######################################
# État Git
#######################################

echo
echo "============================================================"
echo "        linux-ntfs / ntfs-next update"
echo "============================================================"
echo

if ! /usr/bin/git diff --check; then
    echo
    echo "ERREUR : le dépôt contient déjà des erreurs détectées par"
    echo "git diff --check."
    exit 1
fi

echo "Version RPM   : $VERSION"
echo "Release actuel: $CURRENT_RELEASE"
echo

#######################################
# Commit actuellement documenté
#######################################

CURRENT="$(
    /usr/bin/head -n 1 "$DOCUMENTATION" |
    /usr/bin/tr -d '[:space:]'
)"

if ! [[ "$CURRENT" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERREUR : SHA upstream invalide dans :"
    echo "$DOCUMENTATION"
    echo
    echo "Valeur : $CURRENT"
    exit 1
fi

echo "Commit actuel : $CURRENT"

#######################################
# Dernier commit upstream
#######################################

echo "Interrogation de upstream/$BRANCH..."

UPSTREAM="$(
    /usr/bin/git ls-remote "$REPO" "refs/heads/$BRANCH" |
    /usr/bin/awk 'NR == 1 { print $1 }'
)"

if ! [[ "$UPSTREAM" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERREUR : impossible de récupérer le commit upstream."
    exit 1
fi

SHORT="${UPSTREAM:0:8}"

echo "Commit amont  : $UPSTREAM"
echo

#######################################
# Récupération du commit upstream
#######################################

echo "Récupération du commit upstream..."

if ! /usr/bin/git fetch \
    --quiet \
    --no-tags \
    "$REPO" \
    "$UPSTREAM"
then
    echo "ERREUR : impossible de récupérer le commit upstream."
    exit 1
fi

if ! /usr/bin/git cat-file -e "${UPSTREAM}^{commit}" 2>/dev/null; then
    echo "ERREUR : le commit upstream n'est pas disponible localement."
    exit 1
fi

echo "✓ Commit upstream disponible localement."
echo

#######################################
# Aucun changement
#######################################

if [ "$CURRENT" = "$UPSTREAM" ]; then
    echo "✓ Aucun nouveau commit upstream."
    echo "✓ Aucun fichier modifié."
    exit 0
fi

echo "⚠ Nouveau commit détecté : $SHORT"
echo

#######################################
# Informations du commit
#######################################

COMMIT_JSON="$(
    /usr/bin/curl -fsSL \
        "https://api.github.com/repos/namjaejeon/linux-ntfs/commits/$UPSTREAM"
)"

COMMIT_INFO="$(
    printf '%s' "$COMMIT_JSON" |
    /usr/bin/python3 -c '
import json
import os
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

d = json.load(sys.stdin)

date = datetime.fromisoformat(
    d["commit"]["author"]["date"].replace("Z", "+00:00")
)

date = date.astimezone(ZoneInfo(os.environ.get("LOCAL_TZ", "UTC")))

title = d["commit"]["message"].splitlines()[0]

print(date.strftime("%Y-%m-%d %H:%M:%S %z"))
print(title)
'
)"

UPSTREAM_DATE="$(
    printf '%s\n' "$COMMIT_INFO" |
    /usr/bin/head -n 1
)"

UPSTREAM_TITLE="$(
    printf '%s\n' "$COMMIT_INFO" |
    /usr/bin/tail -n 1
)"

CHANGELOG_DATE="$(
    LC_ALL=C /usr/bin/date '+%a %b %d %Y'
)"

echo "Date upstream : $UPSTREAM_DATE"
echo "Sujet          : $UPSTREAM_TITLE"
echo

#######################################
# Nouveau Release
#######################################

NEW_RELEASE="$((CURRENT_RELEASE + 1))"

echo "Nouveau Release : $NEW_RELEASE"
echo

#######################################
# Archive source
#######################################

ARCHIVE_NAME="linux-ntfs-ntfs-next-$SHORT.tar.gz"
ARCHIVE="$SOURCES/$ARCHIVE_NAME"

TMP_DIR="$(/usr/bin/mktemp -d)"

TMP_ARCHIVE="$TMP_DIR/$ARCHIVE_NAME"
TMP_SPEC="$TMP_DIR/linux-ntfs-kmod.spec"
TMP_DOCUMENTATION="$TMP_DIR/ntfs-next-commit.txt"

echo "Création de l'archive source..."
echo

#######################################
# Archive reproductible
#######################################

/usr/bin/git archive \
    --format=tar.gz \
    --prefix=linux-ntfs/ \
    "$UPSTREAM" \
    > "$TMP_ARCHIVE"

if [ ! -s "$TMP_ARCHIVE" ]; then
    echo "ERREUR : archive source vide."
    exit 1
fi

SHA256="$(
    /usr/bin/sha256sum "$TMP_ARCHIVE" |
    /usr/bin/awk '{print $1}'
)"

echo "Archive : $ARCHIVE_NAME"
echo "SHA256  : $SHA256"
echo

#######################################
# Préparation documentation
#######################################

/usr/bin/cat > "$TMP_DOCUMENTATION" <<EOF_DOC
$UPSTREAM
$UPSTREAM_DATE
$UPSTREAM_TITLE
EOF_DOC

#######################################
# Préparation SPEC
#######################################

/usr/bin/cp -a "$SPEC" "$TMP_SPEC"

/usr/bin/python3 - "$TMP_SPEC" "$ARCHIVE_NAME" "$NEW_RELEASE" "$CHANGELOG_DATE" "$UPSTREAM" "$UPSTREAM_TITLE" <<'PY'
import sys
from pathlib import Path

spec_path = Path(sys.argv[1])
archive_name = sys.argv[2]
new_release = sys.argv[3]
changelog_date = sys.argv[4]
commit = sys.argv[5]
title = sys.argv[6]

text = spec_path.read_text()

lines = text.splitlines()

new_lines = []
source_updated = False
release_updated = False
changelog_inserted = False

for line in lines:
    if line.startswith("Release:"):
        new_lines.append(f"Release:        {new_release}%{{?dist}}")
        release_updated = True
        continue

    if line.startswith("Source0:"):
        new_lines.append(f"Source0:        {archive_name}")
        source_updated = True
        continue

    if not changelog_inserted and line == "%changelog":
        new_lines.append("%changelog")
        new_lines.append("")
        new_lines.append(
            f"* {changelog_date} Lyes Sebbane <lyesseb@gmail.com> - {new_release}"
        )
        new_lines.append(
            f"- Update to ntfs-next commit {commit}"
        )
        new_lines.append(
            f"- Update linux-ntfs: {title}"
        )
        changelog_inserted = True
        continue

    new_lines.append(line)

if not release_updated:
    raise SystemExit("ERREUR : ligne Release: introuvable dans le SPEC.")

if not source_updated:
    raise SystemExit("ERREUR : ligne Source0: introuvable dans le SPEC.")

if not changelog_inserted:
    raise SystemExit("ERREUR : section %changelog introuvable dans le SPEC.")

spec_path.write_text("\n".join(new_lines) + "\n")
PY

#######################################
# Validation SPEC préparé
#######################################

echo "Validation du SPEC préparé..."

SPEC_ERROR="$TMP_DIR/spec.error"

if ! /usr/bin/rpmspec -P "$TMP_SPEC" > "$TMP_DIR/spec.expanded" 2> "$SPEC_ERROR"; then
    echo "ERREUR : le SPEC préparé est invalide."
    /usr/bin/cat "$SPEC_ERROR"
    exit 1
fi

if /usr/bin/grep -Eiq '(^|[[:space:]])(erreur|error)[[:space:]:]' "$SPEC_ERROR"; then
    echo "ERREUR : rpmspec a signalé une erreur."
    /usr/bin/cat "$SPEC_ERROR"
    exit 1
fi

echo "✓ SPEC valide."
echo

#######################################
# Validation documentation
#######################################

if ! /usr/bin/head -n 1 "$TMP_DOCUMENTATION" |
    /usr/bin/grep -Eq '^[0-9a-f]{40}$'
then
    echo "ERREUR : documentation générée invalide."
    exit 1
fi

#######################################
# Validation diff avant installation
#######################################

echo "Résumé des modifications prévues :"
echo

/usr/bin/diff -u "$DOCUMENTATION" "$TMP_DOCUMENTATION" || true

echo

/usr/bin/diff -u "$SPEC" "$TMP_SPEC" || true

echo

#######################################
# Installation atomique des fichiers
#######################################

echo "Installation des nouveaux fichiers..."

 /usr/bin/mv "$TMP_ARCHIVE" "$ARCHIVE"
/usr/bin/mv "$TMP_DOCUMENTATION" "$DOCUMENTATION"
/usr/bin/mv "$TMP_SPEC" "$SPEC"

echo
echo "============================================================"
echo "MISE À JOUR TERMINÉE"
echo "============================================================"
echo
echo "Commit précédent : $CURRENT"
echo "Nouveau commit    : $UPSTREAM"
echo "Version           : $VERSION"
echo "Release           : $NEW_RELEASE"
echo "Archive           : $ARCHIVE_NAME"
echo "SHA-256           : $SHA256"
echo
echo "✓ Source mise à jour."
echo "✓ Documentation mise à jour."
echo "✓ SPEC mis à jour."
echo "✓ SPEC validé par rpmspec."
echo
echo "Aucun RPM n'a été construit."
echo "Aucun paquet n'a été installé."
echo

#######################################
# Contrôle final
#######################################

if ! /usr/bin/git diff --check; then
    echo "ERREUR : git diff --check échoue après la mise à jour."
    exit 1
fi

echo "✓ git diff --check : OK"
echo
echo "État Git :"
/usr/bin/git status --short
