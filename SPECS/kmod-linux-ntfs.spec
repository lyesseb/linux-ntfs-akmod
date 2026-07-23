Name:           kmod-linux-ntfs
Version:        20260722
Release:        1%{?dist}
Summary:        Linux NTFS kernel module

License:        GPL-2.0-only
URL:            https://github.com/namjaejeon/linux-ntfs

BuildRequires:  kernel-devel
BuildRequires:  kmodtool
BuildRequires:  redhat-rpm-config

Source0:        linux-ntfs-%{version}.tar.gz

%description
Linux NTFS filesystem kernel module.

%prep
%autosetup -n linux-ntfs

%build
make -C /lib/modules/%{?kernel_version}/build M=$PWD modules

%install
mkdir -p %{buildroot}/lib/modules/%{?kernel_version}/extra
install -m644 ntfs.ko %{buildroot}/lib/modules/%{?kernel_version}/extra/

%files
/lib/modules/%{?kernel_version}/extra/ntfs.ko
