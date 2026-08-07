Projet : linux-ntfs Akmods Fedora

Ce projet fournit un paquet RPM Akmods Fedora pour le pilote
NTFS moderne développé par Namjae Jeon.

Le module généré porte le nom ntfs.ko conformément au nom
historique du pilote NTFS Linux.

Source :
branche ntfs-next de :
https://github.com/namjaejeon/linux-ntfs

Version actuellement intégrée :
- Release RPM : 20260807-1.fc44
- Commit upstream :
  ef4438b3d5525d865e3a1ab62c91e6e65a5c4cc7

Objectif :

Fournir par Akmods le pilote NTFS moderne lorsque Fedora
désactive CONFIG_NTFS_FS dans son noyau.

Ce projet ne fournit pas :
- ntfs-3g (pilote FUSE userspace)
- l'ancien pilote NTFS historique du noyau Linux

Compatibilité testée :
- Fedora 44
- Kernel 7.1.5-201.fc44.x86_64
- Kernel 7.1.6-201.fc44.x86_64

Fonctionnalités validées :
- compilation Akmods
- signature automatique du module
- chargement ntfs.ko
- montage NTFS lecture/écriture
- support des options native_symlink=raw et symlink=wsl
- corrections des problèmes de création/suppression de liens symboliques

Paquets produits :

- akmod-linux-ntfs
- kmod-linux-ntfs
- linux-ntfs-kmod-common

Maintenance :

La procédure de mise à jour vers de nouveaux commits
ntfs-next est documentée dans :

documentation/MAINTENANCE.txt

Le commit upstream actuellement utilisé est conservé dans :

documentation/ntfs-next-commit.txt
