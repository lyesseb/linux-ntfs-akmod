Name:           akmod-linux-ntfs
Version:        20260722
Release:        1%{?dist}
Summary:        Experimental NTFS kernel module akmod

License:        GPL-2.0-only
URL:            https://github.com/namjaejeon/linux-ntfs

Source0:        linux-ntfs-%{version}.tar.gz

BuildArch:      noarch

Requires:       akmods
Requires:       kernel-devel-matched

%description
Experimental NTFS kernel module packaged as an akmod.

%prep
%autosetup -n linux-ntfs

%build

%install
mkdir -p %{buildroot}/usr/src/akmods/%{name}-%{version}

cp -a * %{buildroot}/usr/src/akmods/%{name}-%{version}/

mkdir -p %{buildroot}%{_licensedir}/%{name}
cp -a README.md %{buildroot}%{_licensedir}/%{name}/

%files
/usr/src/akmods/%{name}-%{version}
/usr/share/licenses/%{name}/README.md

%changelog
* Wed Jul 22 2026 Lyes Sebbane <lyesseb@gmail.com> - 20260722-1
- Initial akmod package
