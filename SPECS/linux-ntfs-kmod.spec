%global buildforkernels akmod
%global debug_package %{nil}

%global prjname linux-ntfs

Name:           %{prjname}-kmod
Summary:        Experimental Linux NTFS kernel module
Version:        20260807
Release:        4%{?dist}

License:        GPL-2.0-only
URL:            https://github.com/namjaejeon/linux-ntfs

Source0:        linux-ntfs-ntfs-next-2646c5cb.tar.gz

ExclusiveArch:  x86_64 aarch64

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  elfutils-libelf-devel
BuildRequires:  kmodtool

%if 0%{?local_build}
BuildRequires:  kernel-devel
%else
%{!?kernels:BuildRequires: buildsys-build-rpmfusion-kerneldevpkgs-%{?buildforkernels:%{buildforkernels}}%{!?buildforkernels:current}-%{_target_cpu}}
%endif


%{expand:%(
kmodtool \
    --target %{_target_cpu} \
    --repo rpmfusion \
    --kmodname %{prjname} \
    %{?buildforkernels:--%{buildforkernels}} \
    %{?kernels:--for-kernels "%{?kernels}"} \
    2>/dev/null
)}


%description
Experimental Linux NTFS kernel module.


%package -n %{pkg_kmod_name}-common
Summary:        Common files for %{prjname} kernel module

%description -n %{pkg_kmod_name}-common
Common files needed by the %{prjname} kernel module packages.

%files -n %{pkg_kmod_name}-common
%defattr(-,root,root,-)


%prep

%{?kmodtool_check}

kmodtool \
    --target %{_target_cpu} \
    --repo rpmfusion \
    --kmodname %{prjname} \
    %{?buildforkernels:--%{buildforkernels}} \
    %{?kernels:--for-kernels "%{?kernels}"} \
    2>/dev/null

%setup -q -n linux-ntfs

for kernel_version in %{?kernel_versions}; do
    mkdir ../_kmod_build_${kernel_version%%___*}
    cp -a * ../_kmod_build_${kernel_version%%___*}/
done

%build

for kernel_version in %{?kernel_versions}; do
    make V=1 %{?_smp_mflags} \
         CONFIG_NTFS_FS=m \
         -C ${kernel_version##*___} \
         M=${PWD}/../_kmod_build_${kernel_version%%___*} \
         modules
done

%install

for kernel_version in %{?kernel_versions}; do
    install -D -m 644 \
        ../_kmod_build_${kernel_version%%___*}/ntfs.ko \
        %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/ntfs.ko
done

%{?akmod_install}

%changelog

* Tue Aug 11 2026 Lyes Sebbane <lyesseb@gmail.com> - 4
- Update to ntfs-next commit 2646c5cb2776c44690e45730a519e498941e1ef8
- Update linux-ntfs: ntfs: allow index root relocation

* Mon Aug 10 2026 Lyes Sebbane <lyesseb@gmail.com> - 3
- Update to ntfs-next commit 7e3538d3fed3fb6e8a9d09065060fb82c8b97159
- Update linux-ntfs: ntfs: allow index root relocation
* Fri Aug 07 2026 Lyes Sebbane <lyesseb@gmail.com> - 20260807-2
- Update to ntfs-next commit 0b67ca8f137ef9b440cc31ca02b5d8490dfc057a
- Include upstream fixes for iomap handling, resident MFT locking,
  native symlink handling and non-resident attribute validation
- Rebuild Fedora 44 akmod/kmod packages

* Fri Aug 07 2026 Lyes Sebbane <lyesseb@gmail.com> - 20260807-1
- Update to latest ntfs-next commit ef4438b3d5525d865e3a1ab62c91e6e65a5c4cc7
- Build external ntfs.ko module from Namjae Jeon's development branch
- Preserve Fedora akmods integration

* Wed Jul 22 2026 Lyes Sebbane <lyesseb@gmail.com> - 20260722-1
- Initial RPM Fusion style packaging for linux-ntfs
