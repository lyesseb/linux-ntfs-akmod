VERSION := $(shell cat SOURCES/linux-ntfs.version)
TARBALL := SOURCES/linux-ntfs-$(VERSION).tar.gz

.PHONY: help tarball clean srpm rpm

help:
	@echo ""
	@echo "linux-ntfs-akmod"
	@echo ""
	@echo "make tarball    - rebuild source archive"
	@echo "make srpm       - build source rpm"
	@echo "make rpm        - build binary rpms"
	@echo "make clean      - clean rpmbuild tree"

tarball:
	./scripts/update-upstream.sh

srpm:
	rpmbuild -bs SPECS/akmod-linux-ntfs.spec

rpm:
	rpmbuild -ba SPECS/akmod-linux-ntfs.spec

clean:
	rm -rf ~/rpmbuild/BUILD/*
	rm -rf ~/rpmbuild/BUILDROOT/*
	rm -rf ~/rpmbuild/RPMS/*
	rm -rf ~/rpmbuild/SRPMS/*
