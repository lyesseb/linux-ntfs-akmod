#!/bin/bash

set -euo pipefail

#######################################
# Configuration
#######################################

REPO="https://github.com/namjaejeon/linux-ntfs.git"
BRANCH="ntfs-next"
LOCAL_TZ="Africa/Algiers"

cd ~/Developpement/linux-ntfs-akmod-dev

#######################################
# Commit installé
#######################################

CURRENT=$(head -n 1 documentation/ntfs-next-commit.txt)

CURRENT_INFO=$(git show -s --format='%ci|%s' "$CURRENT" 2>/dev/null)

if [ -z "$CURRENT_INFO" ]; then
    echo "❌ Impossible de trouver le commit installé : $CURRENT"
    exit 1
fi

CURRENT_DATE_RAW="${CURRENT_INFO%%|*}"
CURRENT_TITLE="${CURRENT_INFO#*|}"

CURRENT_DATE=$(date -d "$CURRENT_DATE_RAW" \
    +"%Y-%m-%d %H:%M:%S %Z")

#######################################
# Commit upstream
#######################################

UPSTREAM=$(git ls-remote "$REPO" "refs/heads/$BRANCH" | awk '{print $1}')

if [ -z "$UPSTREAM" ]; then
    echo "❌ Impossible de récupérer le commit upstream"
    exit 1
fi


UPSTREAM_INFO=$(curl -fsSL \
"https://api.github.com/repos/namjaejeon/linux-ntfs/commits/$UPSTREAM" |
python3 -c '
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

d=json.load(sys.stdin)

date=datetime.fromisoformat(
    d["commit"]["author"]["date"].replace("Z","+00:00")
)

date=date.astimezone(ZoneInfo("Africa/Algiers"))

title=d["commit"]["message"].splitlines()[0]

print(
    date.strftime("%Y-%m-%d %H:%M:%S %Z")
    +"|"+title
)
')


UPSTREAM_DATE="${UPSTREAM_INFO%%|*}"
UPSTREAM_TITLE="${UPSTREAM_INFO#*|}"

#######################################
# Affichage
#######################################

echo
echo "════════════════════════════════════════════════════════════"
echo "              linux-ntfs / ntfs-next"
echo "════════════════════════════════════════════════════════════"
echo

echo "VERSION INSTALLÉE"
echo "────────────────────────────────────────────────────────────"
echo "Commit : $CURRENT"
echo "Date   : $CURRENT_DATE"
echo "Sujet  : $CURRENT_TITLE"

echo

echo "DERNIER COMMIT UPSTREAM"
echo "────────────────────────────────────────────────────────────"
echo "Commit : $UPSTREAM"
echo "Date   : $UPSTREAM_DATE"
echo "Sujet  : $UPSTREAM_TITLE"

echo

echo "ÉTAT"
echo "────────────────────────────────────────────────────────────"

if [ "$CURRENT" = "$UPSTREAM" ]; then

    echo "✓ Aucun nouveau commit disponible"

else

    COUNT=$(curl -fsSL \
    "https://api.github.com/repos/namjaejeon/linux-ntfs/compare/$CURRENT...$UPSTREAM" |
    python3 -c '
import json
import sys

d = json.load(sys.stdin)
print(d["total_commits"])
')

    echo "⚠ Nouveau commit disponible"
    echo
    echo "Nombre de nouveaux commits : $COUNT"
    echo
    echo "Comparaison GitHub :"
    echo
    echo "https://github.com/namjaejeon/linux-ntfs/compare/$CURRENT...$UPSTREAM"

fi

echo
echo "════════════════════════════════════════════════════════════"
