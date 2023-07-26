# $id$
#-------------------------------------------------------------------------------
# spec file for the openttd rpm package
#
# Copyright (c) 2007-2008 The OpenTTD developers
#
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself
#
#-------------------------------------------------------------------------------

Name:          openttd
Version:       0.6.2
Release:       head
Group:         Applications/Games
Source:        %{name}-%{version}-source.tar.gz
License:       GPL
URL:           http://www.openttd.org
Packager:      Benedikt Brüggemeier <skidd13@openttd.org>
Vendor:        The OpenTTD developers
Summary:       OpenTTD is an Open Source clone of Chris Sawyer's Transport Tycoon Deluxe

#-------------------------------------------------------------------------------

Requires:      SDL
Requires:      zlib
Requires:      libpng
Requires:      fontconfig
BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: SDL-devel
BuildRequires: zlib-devel
BuildRequires: libpng-devel
BuildRequires: fontconfig-devel
# vendor specific dependencies
%if %{_vendor}=="alt"
# -> Alt Linux: Andrew Kornilov <hiddenman@altlinux.ru>
Requires:      freetype
BuildRequires: freetype-devel
%endif
%if %{_vendor}=="MandrakeSoft" || %{_vendor}=="mandriva"
# -> Mandriva: Gustavo Pichorim Boiko <boiko@mandriva.com>
Requires:      freetype2
BuildRequires: libfreetype6-devel
%endif
%if %{_vendor}=="redhat"
Requires:      freetype
BuildRequires: freetype-devel
%endif
%if %{_vendor}=="suse"
# -> packman: Toni Graffy <toni@links2linux.de>
Requires:      freetype2
BuildRequires: freetype2-devel
%endif

#-------------------------------------------------------------------------------

BuildRoot:     %{_tmppath}/%{name}-%{version}-source-buildroot
Prefix:        /usr

#-------------------------------------------------------------------------------

%description
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. You require the data files of the
original Transport Tycoon Deluxe for Windows or DOS to play the game. You have
to MANUALLY copy them to the game data directory!

OpenTTD is licensed under the GNU General Public License version 2.0. For more
information, see the file 'COPYING' included with every release and source
download of the game.

#-------------------------------------------------------------------------------

%prep
%setup

#-------------------------------------------------------------------------------

%build
./configure \
	--revision=%{version} \
	--prefix-dir="%{prefix}" \
	--binary-dir="bin" \
#	--data-dir="share\games\%{name}" \
#	--doc-dir="share\doc\%{name}" \
#	--icon-dir="share/pixmaps" \
#	--icon-theme-dir="share/icons/hicolor" \
#	--man-dir="share/man/man6" \
#	--menu-dir="share/applications" \
	--install-dir="%{buildroot}" \
	--enable-debug=0 \
#	--menu_group="Game;" \
	--with-sdl \
	--with-zlib \
	--with-png \
	--with-freetype \
	--with-fontconfig
make %{?_smp_mflags}

#-------------------------------------------------------------------------------

%install
make ROOT="%{buildroot}" install

#-------------------------------------------------------------------------------

%post

#-------------------------------------------------------------------------------

%clean
[ -d %{buildroot} -a "%{buildroot}" != "" ] && rm -rf "%{buildroot}"

#-------------------------------------------------------------------------------

%files
%dir %{_datadir}/games/%{name}
%dir %{_datadir}/games/%{name}/data
%dir %{_datadir}/games/%{name}/gm
%dir %{_datadir}/doc/%{name}
%defattr(0644, root, games, 0755)
%attr(0755, root, games) %{_bindir}/%{name}
%doc %{_mandir}/man6/openttd.6.gz
%{_datadir}/applications/%{name}.desktop
%{_datadir}/doc/%{name}/*
%{_datadir}/games/%{name}/lang/*
%{_datadir}/games/%{name}/data/*
%{_datadir}/icons/hicolor/*/apps/openttd.*.png
%{_datadir}/pixmaps/openttd.32.xpm

#-------------------------------------------------------------------------------

%changelog
* Sat Aug 02 2008 Benedikt Brüggemeier <skidd13@openttd.org>

- Updated spec file

* Wed Jul 23 2008 Benedikt Brüggemeier <skidd13@openttd.org>

- Overtook RPM build

* Thu Mar 27 2008 Denis Burlaka <burlaka@yandex.ru>

- Universal spec file
