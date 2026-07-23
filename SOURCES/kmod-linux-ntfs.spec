Name:           kmod-linux-ntfs
Version:        20260722
Release:        1%{?dist}

Summary:        Linux NTFS kernel module

License:        GPL-2.0-only

BuildRequires:  kernel-devel

%global kmod_name linux-ntfs

%description
Kernel module for Linux NTFS filesystem.

%prep
mkdir -p %{_builddir}/%{kmod_name}

cp -a %{_usrsrc}/akmods/akmod-linux-ntfs-%{version}/* .

%build
make -C /usr/src/kernels/%{kversion} M=$PWD modules

%install
mkdir -p %{buildroot}/lib/modules/%{kversion}/extra

install -m 644 ntfs.ko \
 %{buildroot}/lib/modules/%{kversion}/extra/

%files
/lib/modules/%{kversion}/extra/ntfs.ko

%changelog
* Wed Jul 22 2026 Lyes Sebbane <lyesseb@gmail.com>
- Initial kmod package
