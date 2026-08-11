# LINUX-NTFS AKMOD — FEDORA 44

Projet :
linux-ntfs-akmod-dev

Objectif :
Construire, installer et maintenir le pilote linux-ntfs de Namjae Jeon,
branche ntfs-next, sous Fedora au moyen du mécanisme RPM/akmod.

Le projet utilise :

```
- un paquet akmod-linux-ntfs ;
- le mécanisme akmods de Fedora pour générer les kmods correspondant
  aux différents noyaux ;
- un orchestrateur automatique pour surveiller ntfs-next ;
- un timer systemd utilisateur pour effectuer périodiquement cette
  vérification.
```

Le but est de ne pas compiler manuellement ntfs.ko après chaque mise à
jour du noyau.

## VERSION ACTUELLEMENT VALIDÉE

Version RPM :
20260807

Release :
4.fc44

Commit upstream :
2646c5cb2776c44690e45730a519e498941e1ef8

Date :
2026-08-10 16:26:05 +0100

Commit :
ntfs: allow index root relocation

Archive source :
SOURCES/linux-ntfs-ntfs-next-2646c5cb.tar.gz

## STRUCTURE DU PROJET

```
SPECS/
    linux-ntfs-kmod.spec

SOURCES/
    archives linux-ntfs ntfs-next

tools/
    auto-update-ntfs-next.sh
    check-ntfs-next-update.sh
    update-ntfs-next.sh

tools/systemd/
    linux-ntfs-next-update.service
    linux-ntfs-next-update.timer

documentation/
    README.txt
    MAINTENANCE.txt
    INSTALLATION-REINSTALLATION.txt
    ntfs-next-commit.txt
    packages.txt
```

1. MISE À JOUR AUTOMATIQUE

---

L'orchestrateur principal est :

```
tools/auto-update-ntfs-next.sh
```

Il :

```
- vérifie le commit upstream de la branche ntfs-next ;
- récupère le nouveau commit si nécessaire ;
- crée ou met à jour l'archive SOURCE ;
- met à jour le commit documenté ;
- met à jour le SPEC ;
- synchronise l'environnement rpmbuild ;
- construit les RPM lorsqu'un nouveau build est nécessaire ;
- identifie le RPM akmod de manière déterministe ;
- installe le nouvel akmod ;
- déclenche akmods.
```

## 2. IDENTIFICATION DÉTERMINISTE DU RPM

L'orchestrateur ne doit PAS rechercher le RPM produit avec un critère
de date tel que :

```
-newer "$RPMBUILD_SPEC"
```

Ce mécanisme est volontairement abandonné.

La date de modification du SPEC ne constitue pas une preuve fiable
de l'identité du RPM produit par rpmbuild.

L'orchestrateur récupère à la place directement depuis le SPEC :

```
AKMOD_NAME
AKMOD_VERSION
AKMOD_RELEASE
AKMOD_ARCH
```

puis construit le chemin attendu :

```
$RPMBUILD_TOPDIR/RPMS/$AKMOD_ARCH/$AKMOD_NAME-$AKMOD_VERSION-$AKMOD_RELEASE.$AKMOD_ARCH.rpm
```

Le fichier est ensuite explicitement vérifié avant installation.

Cette méthode fournit une identification déterministe du paquet
akmod attendu.

3. VÉRIFICATION DU SCRIPT

---

Avant toute validation :

```
/usr/bin/bash -n tools/auto-update-ntfs-next.sh
```

Puis :

```
/usr/bin/git diff --check
```

Et :

```
/usr/bin/git status --short
```

## 4. CONSTRUCTION MANUELLE

Pour forcer une mise à jour et une construction :

```
cd "$HOME/Developpement/linux-ntfs-akmod-dev"

FORCE_BUILD=1 \
/usr/bin/bash tools/auto-update-ntfs-next.sh
```

Le build RPM est effectué par :

```
/usr/bin/rpmbuild -ba \
    "$HOME/rpmbuild/SPECS/linux-ntfs-kmod.spec"
```

## 5. RPM PRODUITS

Pour la version actuellement validée, les RPM doivent porter :

```
20260807-4.fc44
```

avec notamment :

```
akmod-linux-ntfs-20260807-4.fc44.x86_64.rpm
kmod-linux-ntfs-20260807-4.fc44.x86_64.rpm
linux-ntfs-kmod-common-20260807-4.fc44.x86_64.rpm
```

Le nom exact du RPM akmod installé est déterminé par le SPEC et non
par une recherche basée sur la date des fichiers.

6. INSTALLATION

---

L'orchestrateur installe le RPM akmod identifié automatiquement :

```
/usr/bin/dnf install -y "$AKMOD_RPM"
```

Il vérifie ensuite :

```
/usr/bin/rpm -q \
    akmod-linux-ntfs \
    --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'
```

Puis déclenche :

```
/usr/bin/akmods --force
```

## 7. MÉCANISME AKMOD

Le mécanisme Fedora/akmods est responsable de la génération du kmod
correspondant à chaque noyau.

Vérifier :

```
/usr/bin/systemctl is-enabled akmods.service

/usr/bin/systemctl is-active akmods.service
```

Le service Fedora doit être :

```
enabled
active
```

Le mécanisme ne doit pas être remplacé par une compilation manuelle
du module pour chaque nouveau noyau.

8. VÉRIFICATION DU KMOD

---

Pour le noyau courant :

```
/usr/bin/rpm -q \
    "kmod-linux-ntfs-$(/usr/bin/uname -r)"
```

Puis :

```
/usr/bin/modinfo -F filename ntfs

/usr/bin/modinfo -F vermagic ntfs
```

Le module linux-ntfs doit être installé dans l'arborescence du noyau
correspondant.

9. VÉRIFICATION DU VERMAGIC

---

Comparer :

```
/usr/bin/uname -r
```

avec :

```
/usr/bin/modinfo -F vermagic ntfs
```

Le début du vermagic doit correspondre exactement au noyau courant.

Un module compilé pour un autre noyau ne doit pas être utilisé.

10. VÉRIFICATION DU MODULE

---

Vérifier :

```
/usr/bin/lsmod | /usr/bin/grep '^ntfs '
```

Le pilote attendu est :

```
ntfs
```

et non :

```
ntfs3
```

## 11. VÉRIFICATION DES MONTAGES

Vérifier :

```
/usr/bin/findmnt -t ntfs,ntfs3
```

Les partitions utilisant linux-ntfs doivent apparaître avec :

```
FSTYPE ntfs
```

et non :

```
FSTYPE ntfs3
```

## 12. AUTOMATISATION SYSTEMD

Le projet contient les unités :

```
tools/systemd/linux-ntfs-next-update.service
tools/systemd/linux-ntfs-next-update.timer
```

Le service exécute :

```
/home/deep/Developpement/linux-ntfs-akmod-dev/tools/auto-update-ntfs-next.sh
```

Le timer utilise actuellement :

```
OnBootSec=15min
OnUnitActiveSec=6h
RandomizedDelaySec=30min
Persistent=true
```

Le timer est volontairement distinct du service.

Le service est de type :

```
Type=oneshot
```

Le timer déclenche périodiquement le service.

13. VÉRIFICATION DU TIMER

---

Vérifier :

```
/usr/bin/systemctl --user status \
    linux-ntfs-next-update.timer \
    --no-pager
```

Puis :

```
/usr/bin/systemctl --user list-timers \
    linux-ntfs-next-update.timer \
    --no-pager
```

Le timer doit être :

```
enabled
active (waiting)
```

Le service peut être :

```
inactive (dead)
```

après une exécution réussie, puisque le service est de type oneshot.

Un état :

```
code=exited, status=0/SUCCESS
```

indique une exécution réussie.

14. APRÈS UNE MISE À JOUR DU NOYAU

---

Après installation d'un nouveau noyau Fedora :

```
- le nouveau noyau est installé ;
- akmods détecte l'absence du kmod linux-ntfs correspondant ;
- akmods construit le kmod pour ce noyau ;
- le kmod est installé sous /lib/modules/<kernel>/ ;
- le module peut ensuite être chargé pour ce noyau.
```

Le projet ne doit pas réintroduire une compilation manuelle de
ntfs.ko à chaque mise à jour du noyau.

15. ÉTAT DE RÉFÉRENCE

---

Au moment de cette documentation :

Commit ntfs-next :
2646c5cb2776c44690e45730a519e498941e1ef8

Release RPM :
20260807-4.fc44

L'orchestrateur :
tools/auto-update-ntfs-next.sh

Timer :
linux-ntfs-next-update.timer

Service :
linux-ntfs-next-update.service

Le timer a exécuté correctement le service et le dernier contrôle
a confirmé :

```
✓ Aucun nouveau commit upstream.
✓ Aucun fichier modifié.
✓ Aucun build RPM nécessaire.
```

Le mécanisme d'identification déterministe du RPM akmod est intégré
dans l'orchestrateur.

16. RÈGLE IMPORTANTE

---

Le projet doit conserver la séparation suivante :

```
upstream ntfs-next
        ↓
auto-update-ntfs-next.sh
        ↓
SPEC + SOURCE
        ↓
rpmbuild
        ↓
identification déterministe de l'AKMOD_RPM
        ↓
installation akmod
        ↓
akmods
        ↓
kmod-linux-ntfs pour chaque noyau
```

Il ne faut pas revenir à une recherche du RPM basée sur la date
de modification des fichiers.

Il ne faut pas non plus remplacer akmods par une compilation
manuelle permanente de ntfs.ko.
