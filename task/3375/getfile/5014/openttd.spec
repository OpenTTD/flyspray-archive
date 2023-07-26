# $Id$
#-------------------------------------------------------------------------------
# spec file for the openttd rpm package
#
# Copyright (c) 2007-2009 The OpenTTD developers
#
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself
#
# Note: for (at least) CentOS '#' comments end '\' continue command on new line.
#       So place all '#' commented parameters of e.g. configure to the end.
#
#-------------------------------------------------------------------------------

# use sep. binary name to make branching for openttd-dedicated easier
%define dedicated	0
%define binname 	openttd
# versions with suffixes (-) don't work in rpm
%define srcver 		0.7.4

%if %{dedicated}
Name:          %{binname}-dedicated
%else
Name:          %{binname}
%endif
Version:       %{srcver}
Release:       1%{?dist}
Group:         Amusements/Games
License:       GPLv2
URL:           http://www.openttd.org
Summary:       OpenTTD is an Open Source clone of Chris Sawyer's Transport Tycoon Deluxe

Source:        openttd-%{srcver}-source.tar.bz2

Requires:      %{binname}-data = %{version}
BuildRequires: gcc-c++
BuildRequires: libpng-devel
BuildRequires: zlib-devel

%if !%{dedicated}
Patch0:        desktop-fix.diff

BuildRequires: fontconfig-devel
BuildRequires: SDL-devel

# vendor specific dependencies
 %if 0%{?rhel_version} < 400 || 0%{?rhel_version} > 500
BuildRequires: libicu-devel
 %endif
 %if %{_vendor}=="redhat" || %{_vendor}=="fedora"
BuildRequires: freetype-devel
 %endif
 %if %{_vendor}=="suse" || %{_vendor}=="mandriva"
BuildRequires: freetype2-devel
 %endif

%endif

%if %{dedicated}
Conflicts:	%{binname} %{binname}-gui
%else
Provides:	%{binname}-gui
Conflicts:	%{binname}-dedicated
%endif

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-buildroot

%description
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. To play the game you need either 
the original data from the game or install the recommend package OpenGFX.

OpenTTD is licensed under the GNU General Public License version 2.0. For more
information, see the file 'COPYING' included with every release and source
download of the game.

%if !%{dedicated}
%package data
Summary:       Data package for OpenTTD
Group:         Amusements/Games
 %if 0%{?suse_version} >= 1120 || 0%{?fedora} || 0%{?mdkversion} 
BuildArch: noarch 
 %endif

# recommends works for suse (not sles9) and mandriva, only
 %if 0%{?suse_version} > 910  || %{_vendor}=="mandriva"
Recommends:     openttd-data-opengfx
# for 0.8.0
#Recommends:    openttd-data-opensfx
 %endif

%description data
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. To play the game you need either
the original data from the game or install the recommend package OpenGFX.

This package is required by openttd gui and openttd dedicated package. This 
way it is possible to install a openttd version without SDL requirement.
%endif

%prep
%setup -qn openttd-%{srcver} 
%if !%{dedicated}
%patch0
%endif

%build
# suse sle <10 has no support for makedepend
%if 0%{?sles_version} == 9 || 0%{?sles_version} == 10 || 0%{?rhel_version} == 406
%define 	do_makedepend	0
%else
%define 	do_makedepend	1
%endif
./configure \
	--prefix-dir="%{_prefix}" \
	--binary-name="%{binname}" \
	--enable-strip \
	--binary-dir="bin" \
	--data-dir="share/%{binname}" \
        --doc-dir="share/doc/%{binname}" \
	--with-makedepend="%{do_makedepend}" \
        --menu-group="Game;StrategyGame;" \
	--enable-dedicated="%{dedicated}"
#	--revision="%{ver}%{?prever:-%{prever}}" \
#	--enable-debug=0 \
#	--with-sdl \
#	--with-zlib \
#	--with-png \
#	--with-freetype \
#	--with-fontconfig \
#	--with-icu \
#	--menu-name="OpenTTD" \
#	--doc-dir="share\doc\%{name}" \
#	--icon-dir="share/pixmaps" \
#	--icon-theme-dir="share/icons/hicolor" \
#	--man-dir="share/man/man6" \
#	--menu-dir="share/applications"

make %{?_smp_mflags}

%install
%if %{dedicated}
install -D -m0755 bin/openttd %{buildroot}/%{_bindir}/%{binname}
%else
make install INSTALL_DIR="%{buildroot}"
rm %{buildroot}/%{_datadir}/icons/hicolor/256x256/apps/%{binname}.png
%endif

%clean
rm -rf "%{buildroot}"

%files
%attr(755, root, root) %{_bindir}/%{binname}
%if !%{dedicated}
%defattr(-, root, root)
%dir %{_datadir}/icons/hicolor
%dir %{_datadir}/icons/hicolor/16x16
%dir %{_datadir}/icons/hicolor/16x16/apps
%dir %{_datadir}/icons/hicolor/32x32
%dir %{_datadir}/icons/hicolor/32x32/apps
%dir %{_datadir}/icons/hicolor/48x48
%dir %{_datadir}/icons/hicolor/48x48/apps
%dir %{_datadir}/icons/hicolor/64x64
%dir %{_datadir}/icons/hicolor/64x64/apps
%dir %{_datadir}/icons/hicolor/128x128
%dir %{_datadir}/icons/hicolor/128x128/apps
%{_datadir}/applications/%{binname}.desktop
%{_datadir}/icons/hicolor/128x128/apps/%{binname}.png
%{_datadir}/icons/hicolor/16x16/apps/%{binname}.png
#%{_datadir}/icons/hicolor/256x256/apps/%{binname}.png
%{_datadir}/icons/hicolor/32x32/apps/%{binname}.png
%{_datadir}/icons/hicolor/48x48/apps/%{binname}.png
%{_datadir}/icons/hicolor/64x64/apps/%{binname}.png
%{_datadir}/pixmaps/%{binname}.32.xpm

%files data
%defattr(-, root, root)
%dir %{_datadir}/doc/%{binname}
%dir %{_datadir}/%{binname}
%dir %{_datadir}/%{binname}/lang
%dir %{_datadir}/%{binname}/data
%dir %{_datadir}/%{binname}/gm
%dir %{_datadir}/%{binname}/scripts
%{_datadir}/doc/%{binname}/*
%{_datadir}/%{binname}/lang/*
%{_datadir}/%{binname}/data/*
%{_datadir}/%{binname}/scripts/*
%doc %{_mandir}/man6/%{binname}.6.*
%endif

%changelog
* Mon Dec 14 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.4
- easy support for dedicated branch
* Sun Dec 13 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.4
- let openttd build system make the dektop file
- split the package to data and gui 
* Thu Dec 10 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.4
- upstream update
* Sun Nov 15 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.4-RC1
- upstream update
- disable requires
* Thu Oct 01 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.3
- upstream update 
- disable libicu for RHEL4 
* Sat Sep 26 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.2
- no subfolder games for datadir
- cleanup: no post and postun anymore
- Recommends: opengfx (for suse and mandriva)
- add SUSE support
* Mon Oct 20 2008 Benedikt Brüggemeier <skidd13@openttd.org>
- Added libicu dependency
* Thu Sep 23 2008 Benedikt Brüggemeier <skidd13@openttd.org>
- Merged both versions of the spec file
* Fri Aug 29 2008 Jonathan Coome <maedhros@openttd.org>
- Rewrite spec file from scratch.
* Sat Aug 02 2008 Benedikt Brüggemeier <skidd13@openttd.org>
- Updated spec file
* Thu Mar 27 2008 Denis Burlaka <burlaka@yandex.ru>
- Universal spec file

