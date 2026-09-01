#!/bin/bash

set -euo pipefail

#######################################
# Configuration
#######################################

REPO="https://github.com/namjaejeon/linux-ntfs.git"
BRANCH="ntfs-next"
API_REPO="https://api.github.com/repos/namjaejeon/linux-ntfs"
LOCAL_TZ="Africa/Algiers"

#######################################
# Commit réellement installé
#######################################

CURRENT="$(
    /usr/bin/rpm -q --changelog akmod-linux-ntfs 2>/dev/null \
        | /usr/bin/grep -m 1 -E \
            'Update to ntfs-next commit [0-9a-f]{40}' \
        | /usr/bin/sed -E \
            's/.*Update to ntfs-next commit ([0-9a-f]{40}).*/\1/' \
        || true
)"

if [[ ! "$CURRENT" =~ ^[0-9a-f]{40}$ ]]; then
    echo "❌ Impossible de déterminer le commit réellement installé dans akmod-linux-ntfs"
    exit 1
fi

#######################################
# Informations du commit installé
#######################################

CURRENT_INFO="$(
    /usr/bin/curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 10 \
        --max-time 30 \
        "$API_REPO/commits/$CURRENT" \
        2>/dev/null \
        | /usr/bin/python3 -c '
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

d = json.load(sys.stdin)

date = datetime.fromisoformat(
    d["commit"]["author"]["date"].replace("Z", "+00:00")
)

date = date.astimezone(ZoneInfo("Africa/Algiers"))

title = d["commit"]["message"].splitlines()[0]

print(
    date.strftime("%Y-%m-%d %H:%M:%S %Z")
    + "|"
    + title
)
' \
        || true
)"

if [ -z "$CURRENT_INFO" ]; then
    echo "❌ Impossible de récupérer les informations du commit installé : $CURRENT"
    exit 1
fi

CURRENT_DATE="${CURRENT_INFO%%|*}"
CURRENT_TITLE="${CURRENT_INFO#*|}"

#######################################
# Commit upstream
#######################################

UPSTREAM="$(
    /usr/bin/git ls-remote \
        "$REPO" \
        "refs/heads/$BRANCH" \
        2>/dev/null \
        | /usr/bin/awk '{print $1}' \
        | /usr/bin/head -n 1 \
        || true
)"

if [[ ! "$UPSTREAM" =~ ^[0-9a-f]{40}$ ]]; then
    echo "❌ Impossible de récupérer le commit upstream"
    exit 1
fi

#######################################
# Informations du commit upstream
#######################################

UPSTREAM_INFO="$(
    /usr/bin/curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 10 \
        --max-time 30 \
        "$API_REPO/commits/$UPSTREAM" \
        2>/dev/null \
        | /usr/bin/python3 -c '
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

d = json.load(sys.stdin)

date = datetime.fromisoformat(
    d["commit"]["author"]["date"].replace("Z", "+00:00")
)

date = date.astimezone(ZoneInfo("Africa/Algiers"))

title = d["commit"]["message"].splitlines()[0]

print(
    date.strftime("%Y-%m-%d %H:%M:%S %Z")
    + "|"
    + title
)
' \
        || true
)"

if [ -z "$UPSTREAM_INFO" ]; then
    echo "❌ Impossible de récupérer les informations du commit upstream : $UPSTREAM"
    exit 1
fi

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

    COUNT="$(
        /usr/bin/curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 10 \
            --max-time 30 \
            "$API_REPO/compare/$CURRENT...$UPSTREAM" \
            2>/dev/null \
            | /usr/bin/python3 -c '
import json
import sys

d = json.load(sys.stdin)
print(d["total_commits"])
' \
            || true
    )"

    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo "❌ Impossible de déterminer le nombre de nouveaux commits"
        exit 1
    fi

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
