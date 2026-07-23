Name:           akmod-linux-ntfs
Version:        20260722
Release:        1%{?dist}
Summary:        Linux NTFS kernel module akmod

License:        GPL-2.0-only
URL:            https://github.com/namjaejeon/linux-ntfs

Source0:        linux-ntfs-%{version}.tar.gz
Source1:        kmod-linux-ntfs.spec

BuildArch:      noarch

Requires:       akmods
Requires:       kernel-devel-matched

BuildRequires:  kernel-devel
BuildRequires:  gcc
BuildRequires:  make

%description
Akmod package for building the Linux NTFS filesystem kernel module.

%prep
%autosetup -n linux-ntfs

%build

%install
mkdir -p %{buildroot}%{_usrsrc}/akmods/akmod-linux-ntfs-%{version}

cp -a * %{buildroot}%{_usrsrc}/akmods/akmod-linux-ntfs-%{version}/

install -m644 %{SOURCE1} \
 %{buildroot}%{_usrsrc}/akmods/akmod-linux-ntfs-%{version}/

%files
%{_usrsrc}/akmods/akmod-linux-ntfs-%{version}

%changelog

* Wed Jul 22 2026 Lyes Sebbane <lyesseb@gmail.com>
- Initial akmod package
