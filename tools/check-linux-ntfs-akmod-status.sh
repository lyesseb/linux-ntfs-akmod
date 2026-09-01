#!/usr/bin/env bash

# ==============================================================================
# check-linux-ntfs-akmod-status.sh
#
# Vérification complète de linux-ntfs AKMOD / NTFS-NEXT
#
# Vérifie :
#   - le timer et le service systemd utilisateur NTFS-NEXT ;
#   - la prochaine exécution du timer ;
#   - le noyau courant ;
#   - le paquet AKMOD installé ;
#   - les KMOD linux-ntfs installés ;
#   - le KMOD correspondant exactement au noyau courant ;
#   - le module ntfs détecté par modinfo ;
#   - le vermagic du module ;
#   - le chargement effectif du module ;
#   - les fichiers présents sur disque ;
#   - l'état du service système akmods ;
#   - le journal akmods du boot actuel ;
#   - le commit réellement utilisé par l'AKMOD ;
#   - le dernier commit de linux-ntfs/ntfs-next sur GitHub ;
#   - la comparaison entre le commit AKMOD et le commit upstream ;
#   - la cohérence finale noyau / KMOD / module / upstream.
#
# Ce script est uniquement un outil de vérification.
# Il ne modifie ni le système, ni les paquets, ni le timer.
#
# ==============================================================================


KERNEL="$(/usr/bin/uname -r)"

MODULE_DIR="/lib/modules/${KERNEL}/extra/linux-ntfs"

UPSTREAM_REPO="https://github.com/namjaejeon/linux-ntfs.git"
UPSTREAM_BRANCH="ntfs-next"


printf '\n%s\n' '=========================================='
printf '%s\n' '=== VÉRIFICATION COMPLÈTE LINUX-NTFS ==='
printf '%s\n' '=== AKMOD ET AUTOMATISATION NTFS-NEXT ==='
printf '%s\n' '=========================================='


# ==============================================================================
# AUTOMATISATION NTFS-NEXT
# ==============================================================================

printf '%s\n' '=== AUTOMATISATION NTFS-NEXT UTILISATEUR ==='
printf '%s\n' '=========================================='

/usr/bin/systemctl --user status \
    linux-ntfs-next-update.timer \
    linux-ntfs-next-update.service \
    --no-pager || true

printf '\n%s\n' '========================================'
printf '%s\n' '=== PROCHAINE EXÉCUTION DU TIMER ==='
printf '%s\n' '========================================'
printf '\n'

/usr/bin/systemctl --user list-timers \
    linux-ntfs-next-update.timer \
    --no-pager || true


# ==============================================================================
# NOYAU COURANT
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== NOYAU COURANT ==='
printf '%s\n' '========================================'

printf '%s\n' "$KERNEL"


# ==============================================================================
# AKMOD INSTALLÉ
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== AKMOD INSTALLÉ ==='
printf '%s\n' '========================================'

/usr/bin/rpm -q akmod-linux-ntfs \
    --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' || true


# ==============================================================================
# KMODS INSTALLÉS
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== KMODS INSTALLÉS ==='
printf '%s\n' '========================================'

/usr/bin/rpm -qa \
    | /usr/bin/grep '^kmod-linux-ntfs' \
    | /usr/bin/sort -V || true


# ==============================================================================
# KMOD DU NOYAU COURANT
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== KMOD POUR LE NOYAU COURANT ==='
printf '%s\n' '========================================'

/usr/bin/rpm -qa \
    | /usr/bin/grep "^kmod-linux-ntfs-${KERNEL}-" \
    | /usr/bin/sort -V || true


# ==============================================================================
# MODULE NTFS
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== MODULE NTFS ==='
printf '%s\n' '========================================'

/usr/bin/modinfo ntfs \
    | /usr/bin/grep -E '^(filename|version|vermagic):' || true

printf '\n%s\n' '========================================'
printf '%s\n' '=== VERMAGIC ATTENDU ==='
printf '%s\n' '========================================'

printf '%s\n' "$KERNEL"


# ==============================================================================
# MODULE CHARGÉ
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== MODULE CHARGÉ ==='
printf '%s\n' '========================================'

/usr/bin/lsmod \
    | /usr/bin/grep '^ntfs ' || true


# ==============================================================================
# FICHIERS SUR DISQUE
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== FICHIERS SUR DISQUE ==='
printf '%s\n' '========================================'

if [ -d "$MODULE_DIR" ]; then

    /usr/bin/find "$MODULE_DIR" \
        -maxdepth 1 \
        -type f \
        -printf '%f\n' \
        2>/dev/null || true

else

    printf '%s\n' \
        "ATTENTION : répertoire absent : $MODULE_DIR"

fi


# ==============================================================================
# SERVICE AKMODS
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== SERVICE AKMODS ==='
printf '%s\n' '========================================'

/usr/bin/systemctl status \
    akmods.service \
    --no-pager || true


# ==============================================================================
# JOURNAL AKMODS
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== JOURNAL AKMODS — BOOT ACTUEL ==='
printf '%s\n' '========================================'

/usr/bin/journalctl \
    -b \
    -u akmods.service \
    --no-pager || true


# ==============================================================================
# COMMIT RÉELLEMENT UTILISÉ PAR L'AUTOMATISATION
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== VERSION LINUX-NTFS / NTFS-NEXT ==='
printf '%s\n' '========================================'

# ------------------------------------------------------------------------------
# Récupération du commit réellement embarqué dans l'AKMOD installé.
#
# Le journal du service d'automatisation ne constitue PAS une source fiable
# pour cette information : auto-update-ntfs-next.sh ne journalise pas
# "Commit AKMOD" ni "Commit attendu".
#
# Le RPM AKMOD contient en revanche dans son changelog la ligne générée
# par le SPEC :
#
#   Update to ntfs-next commit <SHA>
#
# C'est donc le paquet réellement installé qui fait foi.
# ------------------------------------------------------------------------------

INSTALLED_COMMIT="$(
    /usr/bin/rpm -q --changelog akmod-linux-ntfs 2>/dev/null \
        | /usr/bin/grep -m 1 -E \
            'Update to ntfs-next commit [0-9a-f]{40}' \
        | /usr/bin/sed -E \
            's/.*Update to ntfs-next commit ([0-9a-f]{40}).*/\1/' \
        || true
)"

# ------------------------------------------------------------------------------
# Le commit réellement installé est notre référence locale.
# La comparaison avec le véritable commit attendu se fait ensuite
# directement avec le commit actuellement présent sur upstream ntfs-next.
# ------------------------------------------------------------------------------

EXPECTED_COMMIT="$INSTALLED_COMMIT"

# ------------------------------------------------------------------------------
# Récupération du dernier commit réellement présent sur upstream ntfs-next.
#
# git ls-remote interroge directement la référence distante :
#
#   refs/heads/ntfs-next
#
# Le SHA retourné est donc la source de vérité pour l'état actuel de la branche.
# ------------------------------------------------------------------------------

UPSTREAM_COMMIT="$(
    /usr/bin/git ls-remote         "https://github.com/namjaejeon/linux-ntfs.git"         "refs/heads/ntfs-next" 2>/dev/null         | /usr/bin/awk '{print $1}'         | /usr/bin/head -n 1         || true
)"

# ------------------------------------------------------------------------------
# Les informations descriptives du commit (intitulé/date) restent facultatives.
# Elles ne participent PAS à la détermination du SHA.
# ------------------------------------------------------------------------------

UPSTREAM_SUBJECT=""
UPSTREAM_DATE=""

if [[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    UPSTREAM_COMMIT_JSON="$(
        /usr/bin/curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 10 \
            --max-time 30 \
            "https://api.github.com/repos/namjaejeon/linux-ntfs/commits/${UPSTREAM_COMMIT}" \
            2>/dev/null || true
    )"

    UPSTREAM_SUBJECT="$(
        printf '%s\n' "$UPSTREAM_COMMIT_JSON" \
            | /usr/bin/grep '"message":' \
            | /usr/bin/head -n 1 \
            | /usr/bin/sed -E 's/.*"message":[[:space:]]*"([^"]*)".*/\1/' \
            | /usr/bin/sed 's/\\n.*//'
    )"

    UPSTREAM_DATE="$(
        printf '%s\n' "$UPSTREAM_COMMIT_JSON" \
            | /usr/bin/grep '"date":' \
            | /usr/bin/head -n 1 \
            | /usr/bin/sed -E 's/.*"date":[[:space:]]*"([^"]+)".*/\1/'
    )"
fi

printf '%s\n' '=== COMMIT INSTALLÉ ==='
printf '%s\n' '========================================'

if [[ "$INSTALLED_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s\n' "Commit AKMOD installé : $INSTALLED_COMMIT"
else
    printf '%s\n' 'Commit AKMOD installé : NON DÉTERMINÉ'
fi

printf '%s\n' 'Intitulé :'

if [[ "$INSTALLED_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    INSTALLED_COMMIT_JSON="$(
        /usr/bin/curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 10 \
            --max-time 30 \
            "https://api.github.com/repos/namjaejeon/linux-ntfs/commits/${INSTALLED_COMMIT}" \
            2>/dev/null || true
    )"

     INSTALLED_SUBJECT="$(
         printf '%s\n' "$INSTALLED_COMMIT_JSON" \
             | /usr/bin/grep '"message":' \
             | /usr/bin/head -n 1 \
             | /usr/bin/sed -E 's/.*"message":[[:space:]]*"([^"]*)".*/\1/' \
             | /usr/bin/sed 's/\\n.*//'
     )"

    INSTALLED_DATE="$(
        printf '%s\n' "$INSTALLED_COMMIT_JSON" \
            | /usr/bin/grep '"date":' \
            | /usr/bin/head -n 1 \
            | /usr/bin/sed -E 's/.*"date":[[:space:]]*"([^"]+)".*/\1/'
    )"

    printf '%s\n' "${INSTALLED_SUBJECT:-NON DISPONIBLE}"
    printf '%s\n' "Date : ${INSTALLED_DATE:-NON DISPONIBLE}"
else
    printf '%s\n' 'NON DISPONIBLE'
fi

printf '\n%s\n' '========================================'
printf '%s\n' '=== COMMIT ATTENDU PAR L’AUTOMATISATION ==='
printf '%s\n' '========================================'

if [[ "$EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s\n' "Commit attendu : $EXPECTED_COMMIT"
else
    printf '%s\n' 'Commit attendu : NON DÉTERMINÉ'
fi

printf '\n%s\n' '========================================'
printf '%s\n' '=== DERNIER COMMIT UPSTREAM ==='
printf '%s\n' '========================================'

printf '%s\n' 'Dépôt : https://github.com/namjaejeon/linux-ntfs.git'
printf '%s\n' 'Branche : ntfs-next'

if [[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s\n' "Dernier commit upstream : $UPSTREAM_COMMIT"
    printf '%s\n' "Intitulé : ${UPSTREAM_SUBJECT:-NON DISPONIBLE}"
    printf '%s\n' "Date : ${UPSTREAM_DATE:-NON DISPONIBLE}"
else
    printf '%s\n' 'Dernier commit upstream : IMPOSSIBLE À DÉTERMINER'
    printf '%s\n' 'Intitulé : IMPOSSIBLE À DÉTERMINER'
    printf '%s\n' 'Date : IMPOSSIBLE À DÉTERMINER'
fi

printf '\n%s\n' '========================================'
printf '%s\n' '=== COMPARAISON AKMOD / UPSTREAM ==='
printf '%s\n' '========================================'

COMMIT_OK=false
COMMIT_STATUS="INCONNU"

if [[ "$INSTALLED_COMMIT" =~ ^[0-9a-f]{40}$ ]] \
    && [[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]
then

    if [ "$INSTALLED_COMMIT" = "$UPSTREAM_COMMIT" ]; then

        COMMIT_OK=true
        COMMIT_STATUS="À JOUR"

        printf '%s\n' \
            '✓ OK : le pilote installé correspond exactement au dernier commit upstream.'

        printf '%s\n' \
            "Dernière modification : ${UPSTREAM_SUBJECT:-NON DISPONIBLE}"

    else

        COMMIT_OK=false
        COMMIT_STATUS="EN RETARD"

        printf '%s\n' \
            '⚠ ATTENTION : le pilote installé ne correspond pas au dernier commit upstream.'

        printf '%s\n' \
            "Commit installé : $INSTALLED_COMMIT"

        printf '%s\n' \
            "Dernier upstream : $UPSTREAM_COMMIT"

        printf '%s\n' \
            "Nouveauté upstream : ${UPSTREAM_SUBJECT:-NON DISPONIBLE}"

    fi

else

    COMMIT_OK=false
    COMMIT_STATUS="INCONNU"

    printf '%s\n' \
        '⚠ ATTENTION : comparaison impossible.'

    printf '%s\n' \
        'Impossible de déterminer l’un des deux commits.'

fi

printf '\n%s\n' '========================================'
printf '%s\n' '=== VÉRIFICATION DE COHÉRENCE ==='
printf '%s\n' '========================================'


MODINFO_OUTPUT="$(
    /usr/bin/modinfo ntfs \
        2>/dev/null \
        || true
)"


MODULE_FILENAME="$(
    printf '%s\n' "$MODINFO_OUTPUT" \
        | /usr/bin/grep '^filename:' \
        || true
)"


MODULE_VERMAGIC="$(
    printf '%s\n' "$MODINFO_OUTPUT" \
        | /usr/bin/grep '^vermagic:' \
        || true
)"


MODULE_OK=false
KMOD_OK=false
VERMAGIC_OK=false
LOADED_OK=false


# ------------------------------------------------------------------------------
# Module situé dans l'arborescence du noyau courant
# ------------------------------------------------------------------------------

if printf '%s\n' "$MODULE_FILENAME" \
    | /usr/bin/grep -q "/lib/modules/${KERNEL}/"; then

    MODULE_OK=true

fi


# ------------------------------------------------------------------------------
# KMOD correspondant au noyau courant
# ------------------------------------------------------------------------------

if /usr/bin/rpm -qa \
    | /usr/bin/grep -q "^kmod-linux-ntfs-${KERNEL}-"; then

    KMOD_OK=true

fi


# ------------------------------------------------------------------------------
# Vermagic
# ------------------------------------------------------------------------------

if printf '%s\n' "$MODULE_VERMAGIC" \
    | /usr/bin/grep -qF "$KERNEL"; then

    VERMAGIC_OK=true

fi


# ------------------------------------------------------------------------------
# Module chargé
# ------------------------------------------------------------------------------

if /usr/bin/lsmod \
    | /usr/bin/grep -q '^ntfs '; then

    LOADED_OK=true

fi


# ==============================================================================
# RÉSULTAT
# ==============================================================================

printf '\n%s\n' '=== RÉSULTAT ==='


printf '%-45s %s\n' \
    'KMOD pour le noyau courant :' \
    "$KMOD_OK"


printf '%-45s %s\n' \
    'Module trouvé pour le noyau courant :' \
    "$MODULE_OK"


printf '%-45s %s\n' \
    'Vermagic correspondant :' \
    "$VERMAGIC_OK"


printf '%-45s %s\n' \
    'Module actuellement chargé :' \
    "$LOADED_OK"


printf '%-45s %s\n' \
    'Commit AKMOD = commit upstream :' \
    "$COMMIT_OK"


printf '%-45s %s\n' \
    'État upstream :' \
    "$COMMIT_STATUS"


printf '\n'


# ==============================================================================
# CONCLUSION TECHNIQUE
# ==============================================================================

if [ "$KMOD_OK" = true ] \
    && [ "$MODULE_OK" = true ] \
    && [ "$VERMAGIC_OK" = true ]; then

    printf '%s\n' \
        '✓ OK : le module NTFS est correctement installé pour le noyau courant.'

    printf '%s\n' \
        '✓ OK : le KMOD et le vermagic correspondent au noyau courant.'

else

    printf '%s\n' \
        '✗ ERREUR : incohérence détectée entre le noyau courant et linux-ntfs.'

fi


# ==============================================================================
# CONCLUSION MODULE CHARGÉ
# ==============================================================================

if [ "$LOADED_OK" = true ]; then

    printf '%s\n' \
        '✓ OK : le module NTFS est actuellement chargé.'

else

    printf '%s\n' \
        'ℹ INFO : le module NTFS n’est pas actuellement chargé.'

fi


# ==============================================================================
# CONCLUSION UPSTREAM
# ==============================================================================

if [ "$COMMIT_OK" = true ]; then

    printf '%s\n' \
        '✓ OK : le pilote installé correspond au dernier commit ntfs-next upstream.'

elif [ "$COMMIT_STATUS" = "EN RETARD" ]; then

    printf '%s\n' \
        '⚠ ATTENTION : un nouveau commit ntfs-next est disponible upstream.'

else

    printf '%s\n' \
        'ℹ INFO : la correspondance avec upstream n’a pas pu être vérifiée.'

fi


# ==============================================================================
# FIN
# ==============================================================================

printf '\n%s\n' '========================================'
printf '%s\n' '=== FIN DE LA VÉRIFICATION ==='
printf '%s\n' '========================================'
