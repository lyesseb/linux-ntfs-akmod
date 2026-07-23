#!/usr/bin/env bash
set -euo pipefail

VERSION=$(date +%Y%m%d)

WORK=$(mktemp -d)

git clone --depth=1 \
https://github.com/namjaejeon/linux-ntfs.git \
"$WORK/linux-ntfs"

echo "$VERSION" > SOURCES/linux-ntfs.version

tar \
    --exclude=.git \
    -C "$WORK" \
    -czf SOURCES/linux-ntfs-${VERSION}.tar.gz \
    linux-ntfs

echo
echo "Version : $VERSION"
echo "Archive : SOURCES/linux-ntfs-${VERSION}.tar.gz"

rm -rf "$WORK"
