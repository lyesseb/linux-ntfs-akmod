%define kmod_name linux-ntfs
%define kmod_version 20260722

Name:           akmod-%{kmod_name}
Version:        %{kmod_version}
Release:        1%{?dist}

Summary:        Akmod package for Linux NTFS kernel module
License:        GPL-2.0-only

BuildArch:      noarch

BuildRequires:  rpm-build
BuildRequires:  kernel-devel
BuildRequires:  gcc
BuildRequires:  make

Source0:        linux-ntfs-%{kmod_version}.tar.gz
Source1:        kmod-linux-ntfs.spec
Source2:        kmod-linux-ntfs-%{kmod_version}-%{release}.src.rpm

%global debug_package %{nil}

%description
Akmod package for building the Linux NTFS kernel module automatically
for installed Fedora kernels.

%prep
%autosetup -n linux-ntfs


%build
# Nothing to build here.
# The module is built later by akmods.


%install

mkdir -p %{buildroot}/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}

cp -a * \
%{buildroot}/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}/


install -D -m644 %{SOURCE1} \
%{buildroot}/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}/kmod-linux-ntfs.spec


install -D -m644 %{SOURCE2} \
%{buildroot}/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}-%{release}.src.rpm


ln -s linux-ntfs-kmod-%{kmod_version}-%{release}.src.rpm \
%{buildroot}/usr/src/akmods/linux-ntfs-kmod.latest


%files
/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}
/usr/src/akmods/linux-ntfs-kmod-%{kmod_version}-%{release}.src.rpm
/usr/src/akmods/linux-ntfs-kmod.latest


%changelog

* Thu Jul 23 2026 Lyes Sebbane <lyesseb@gmail.com> - 20260722-1
- Initial akmod package
