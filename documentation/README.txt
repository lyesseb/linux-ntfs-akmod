Projet : linux-ntfs Akmods Fedora

Ce paquet compile le pilote NTFS moderne de Namjae Jeon.

Le module généré porte le nom ntfs.ko conformément au noyau Linux 7.1.

Source :
branche ntfs-next de https://github.com/namjaejeon/linux-ntfs

Objectif :
fournir par Akmods le pilote NTFS moderne lorsque Fedora
désactive CONFIG_NTFS_FS dans son noyau.

Ce n'est pas ntfs-3g.
Ce n'est pas l'ancien pilote NTFS historique.

Paquets produits :
- akmod-linux-ntfs
- kmod-linux-ntfs
- linux-ntfs-kmod-common
