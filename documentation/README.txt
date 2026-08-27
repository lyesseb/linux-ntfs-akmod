# LINUX-NTFS AKMOD — FEDORA 44

Projet :
linux-ntfs-akmod-dev

Objectif :
Construire, installer et maintenir le pilote linux-ntfs de Namjae Jeon,
branche ntfs-next, sous Fedora au moyen du mécanisme RPM/akmod.

Le projet utilise :

```
- un paquet akmod-linux-ntfs ;
- un paquet linux-ntfs-kmod-common ;
- le mécanisme akmods de Fedora pour générer les kmods correspondant
  aux différents noyaux ;
- un orchestrateur automatique pour surveiller ntfs-next ;
- un timer systemd utilisateur pour effectuer périodiquement cette
  vérification ;
- un helper systemd root et Polkit pour installer les RPM produits ;
- un bootstrap de dépendances pour les installations sur une nouvelle
  machine.
```

Le but est de ne pas compiler manuellement ntfs.ko après chaque mise à
jour du noyau.

## VERSION ACTUELLEMENT VALIDÉE

Version RPM :
20260807

Release :
13.fc44

Commit upstream :
4e41ce6f7a7711299e12dcb9c77533a7ab273913

Date :
2026-08-27

Commit :
ntfs: compute bi_sector in 512-byte units

Archive source :
SOURCES/linux-ntfs-ntfs-next-4e41ce6f.tar.gz

Patch local :
SOURCES/0001-ntfs-fix-bio-sector-callers.patch

Le patch local adapte les appels à ntfs_bytes_to_bio_sector()
au changement de représentation de bi_sector en secteurs de
512 octets.

Commit du projet :
5194f61

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
    install-dependencies.sh
    install-systemd-user.sh
    linux-ntfs-akmod-install

tools/systemd/
    linux-ntfs-next-update.service.in
    linux-ntfs-next-update.timer
    linux-ntfs-akmod-install@.service.in

tools/polkit/
    49-linux-ntfs-akmod.rules

documentation/
    README.txt
    MAINTENANCE.txt
    INSTALLATION-REINSTALLATION.txt
    ntfs-next-commit.txt
    packages.txt
```

## 1. MISE À JOUR AUTOMATIQUE

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
- demande l'installation des RPM par le service systemd root ;
- ne lance pas directement akmods.
```

Le script peut être exécuté manuellement avec :

```
cd "$HOME/Developpement/linux-ntfs-akmod-dev"
FORCE_BUILD=1 /usr/bin/bash tools/auto-update-ntfs-next.sh
```

## 2. IDENTIFICATION DÉTERMINISTE DU RPM

L'orchestrateur ne doit PAS rechercher le RPM produit avec un critère
de date tel que :

```
-newer "$RPMBUILD_SPEC"
```

La date de modification du SPEC ne constitue pas une preuve fiable de
l'identité du RPM produit par rpmbuild.

L'orchestrateur récupère directement depuis le SPEC :

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

Le fichier est ensuite explicitement vérifié comme RPM akmod attendu.

Cette méthode fournit une identification déterministe du paquet akmod.

## 3. INSTALLATION DES DÉPENDANCES

Le bootstrap est :

```
tools/install-dependencies.sh
```

Il est exécuté par l'utilisateur cible, sans sudo direct, et utilise sudo
uniquement pour les opérations système nécessaires.

Il vérifie ou installe notamment :

```
akmods
kmodtool
rpm-build
rpmdevtools
git
curl
python3
gcc
make
elfutils-libelf-devel
buildsys-build-rpmfusion
kernel-devel du noyau courant
```

Il s'assure également que RPM Fusion Free est disponible.

### NTFS-3G

Le projet doit utiliser le type de filesystem `ntfs` fourni par le
module linux-ntfs du noyau. Pour éviter que le helper `mount.ntfs`
fourni par ntfs-3g détourne les montages vers FUSE, l'installateur
supprime `ntfs-3g` lorsqu'il est présent.

Après cette suppression, les montages graphiques UDisks/Dolphin doivent
utiliser :

```
Dolphin / UDisks
        ↓
      ntfs
        ↓
linux-ntfs.ko
```

et non :

```
ntfs-3g
   ↓
fuseblk
```

Aucune entrée NTFS dans `/etc/fstab` n'est requise par le projet pour
obtenir le montage graphique automatique.

## 4. VÉRIFICATION DES SCRIPTS

Avant toute validation :

```
/usr/bin/bash -n tools/auto-update-ntfs-next.sh
/usr/bin/bash -n tools/install-dependencies.sh
/usr/bin/bash -n tools/install-systemd-user.sh
/usr/bin/bash -n tools/linux-ntfs-akmod-install
```

Puis :

```
/usr/bin/git diff --check
/usr/bin/git status --short
```

## 5. RPM PRODUITS

Pour la version actuellement validée, les RPM doivent porter :

```
20260807-13.fc44
```

avec notamment :

```
akmod-linux-ntfs-20260807-13.fc44.x86_64.rpm
kmod-linux-ntfs-20260807-13.fc44.x86_64.rpm
linux-ntfs-kmod-common-20260807-13.fc44.x86_64.rpm
```

Pour un noyau précis, un paquet KMOD correspondant doit être présent,
par exemple :

```
kmod-linux-ntfs-<kernel>-20260807-13.fc44.x86_64
```

## 6. INSTALLATION DU MÉCANISME

L'entrée utilisateur est :

```
/usr/bin/bash tools/install-systemd-user.sh
```

Elle :

```
- vérifie les fichiers nécessaires ;
- lance install-dependencies.sh ;
- installe le helper root ;
- installe le service systemd root ;
- installe la règle Polkit ;
- installe le service systemd utilisateur ;
- installe et active le timer ;
- recharge les unités concernées.
```

Le script détermine automatiquement le répertoire du projet et le nom
de l'utilisateur courant.

## 7. INSTALLATION DES RPM PAR SYSTEMD

Le service root est :

```
linux-ntfs-akmod-install@.service
```

Le helper est installé dans :

```
/usr/libexec/linux-ntfs-akmod-install
```

Le helper :

```
- identifie le RPM akmod produit ;
- identifie le KMOD générique correspondant ;
- identifie le paquet linux-ntfs-kmod-common correspondant ;
- transmet les trois RPM à dnf5 ;
- ne lance pas directement akmods.
```

Le service est de type `oneshot` et est invoqué par l'orchestrateur
après une construction réussie.

## 8. MÉCANISME AKMOD

Le mécanisme Fedora/akmods est responsable de la génération du kmod
correspondant à chaque noyau.

Le projet ne remplace pas akmods par une compilation manuelle
permanente de ntfs.ko.

Vérifier notamment :

```
/usr/bin/systemctl is-enabled akmods.service
/usr/bin/systemctl is-active akmods.service
```

## 9. VÉRIFICATION DU KMOD

Pour le noyau courant :

```
/usr/bin/rpm -q "kmod-linux-ntfs-$(/usr/bin/uname -r)"
/usr/bin/modinfo -F filename ntfs
/usr/bin/modinfo -F vermagic ntfs
```

Le module linux-ntfs doit être installé dans l'arborescence du noyau
correspondant.

## 10. VÉRIFICATION DU VERMAGIC

Comparer :

```
/usr/bin/uname -r
```

avec :

```
/usr/bin/modinfo -F vermagic ntfs
```

Le début du vermagic doit correspondre exactement au noyau courant.

## 11. VÉRIFICATION DU MODULE

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

## 12. VÉRIFICATION DES MONTAGES

Vérifier :

```
/usr/bin/findmnt -t ntfs
/usr/bin/findmnt -t fuseblk || true
```

Les partitions utilisant linux-ntfs doivent apparaître avec :

```
FSTYPE ntfs
```

Un montage `fuseblk` indique que le chemin ntfs-3g/FUSE est utilisé et
n'est pas le comportement attendu par ce projet.

## 13. AUTOMATISATION SYSTEMD UTILISATEUR

Le projet contient :

```
tools/systemd/linux-ntfs-next-update.service.in
tools/systemd/linux-ntfs-next-update.timer
tools/install-systemd-user.sh
```

Le service exécute :

```
tools/auto-update-ntfs-next.sh
```

Le timer est distinct du service et le service est de type `oneshot`.

Vérifier :

```
/usr/bin/systemctl --user status \
    linux-ntfs-next-update.timer \
    --no-pager

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

## 14. APRÈS UNE MISE À JOUR DU NOYAU

Après installation d'un nouveau noyau Fedora :

```
- le nouveau noyau est installé ;
- akmods détecte l'absence du kmod linux-ntfs correspondant ;
- akmods construit le kmod pour ce noyau ;
- le kmod est installé sous /lib/modules/<kernel>/ ;
- le module peut ensuite être chargé pour ce noyau.
```

Le projet ne doit pas réintroduire une compilation manuelle de ntfs.ko
à chaque mise à jour du noyau.

## 15. ÉTAT DE RÉFÉRENCE

Au moment de cette documentation :

```
Commit ntfs-next : 4e41ce6f7a7711299e12dcb9c77533a7ab273913
Release RPM      : 20260807-13.fc44
Commit projet    : 5194f61
```

L'orchestrateur :

```
tools/auto-update-ntfs-next.sh
```

Timer :

```
linux-ntfs-next-update.timer
```

Service :

```
linux-ntfs-next-update.service
```

Installateur :

```
tools/install-systemd-user.sh
```

## 16. VALIDATION MULTI-MACHINES

Le mécanisme d'installation et le montage NTFS natif ont été validés
sur quatre machines Fedora utilisées pour le projet.

Le scénario validé sur une installation nouvelle est :

```
clone du projet
        ↓
install-systemd-user.sh
        ↓
install-dependencies.sh
        ↓
ntfs-3g absent
        ↓
rpmbuild
        ↓
installation systemd des RPM
        ↓
kmod-linux-ntfs
        ↓
Dolphin / UDisks
        ↓
FSTYPE ntfs
        ↓
pas de fuseblk
```

Cette validation ne remplace pas des tests supplémentaires avec de
nouveaux noyaux ou de nouvelles versions de Fedora.

## 17. RÈGLE IMPORTANTE

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
service systemd root
        ↓
installation common + akmod + kmod
        ↓
akmods
        ↓
kmod-linux-ntfs pour chaque noyau
```

Il ne faut pas revenir à une recherche du RPM basée sur la date de
modification des fichiers.

Il ne faut pas non plus remplacer akmods par une compilation manuelle
permanente de ntfs.ko.

Il ne faut pas réintroduire ntfs-3g comme handler du filesystem
`ntfs` ni ajouter des entrées NTFS dans `/etc/fstab` comme mécanisme
obligatoire de montage graphique.
