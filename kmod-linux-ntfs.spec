%global kmod_name linux-ntfs
%global kmod_version 20260722

Name:           kmod-%{kmod_name}
Version:        %{kmod_version}
Release:        1%{?dist}
Summary:        Linux NTFS kernel module

License:        GPL-2.0-only

BuildRequires:  kernel-devel
BuildRequires:  gcc
BuildRequires:  make

Requires:       kernel-uname-r = %{kver}

%description
Kernel module for Linux NTFS filesystem.

%prep

%build
make -C /usr/src/kernels/%{kver} \
    M=%{_usrsrc}/akmods/akmod-linux-ntfs-%{version} \
    modules

%install
mkdir -p %{buildroot}/lib/modules/%{kver}/extra/linux-ntfs

install -m644 \
    %{_usrsrc}/akmods/akmod-linux-ntfs-%{version}/ntfs.ko \
    %{buildroot}/lib/modules/%{kver}/extra/linux-ntfs/

%files
/lib/modules/%{kver}/extra/linux-ntfs/ntfs.ko

%changelog
* Wed Jul 22 2026 Lyes Sebbane
- Initial kmod package
