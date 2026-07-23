Name:           akmod-linux-ntfs
Version:        20260722
Release:        1%{?dist}
Summary:        Experimental NTFS kernel module akmod

License:        GPL-2.0-only
URL:            https://github.com/namjaejeon/linux-ntfs

Source0:        linux-ntfs-%{version}.tar.gz
Source1:        kmod-linux-ntfs.spec

BuildRequires:  akmods
BuildRequires:  kmodtool

Requires:       akmods

%description
Akmod package building the Linux NTFS filesystem kernel module.

%prep
%autosetup -n linux-ntfs

%build

%install
mkdir -p %{buildroot}%{_usrsrc}/akmods

install -m644 %{SOURCE1} \
 %{buildroot}%{_usrsrc}/akmods/

%files
%{_usrsrc}/akmods/kmod-linux-ntfs.spec

%changelog
* Wed Jul 22 2026 Lyes Sebbane <lyesseb@gmail.com>
- Initial akmod package
