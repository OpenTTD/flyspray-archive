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

Name:          openttd
Version:       0.7.2
Release:       1%{?dist}

Group:         Amusements/Games
License:       GPLv2
URL:           http://www.openttd.org
Summary:       OpenTTD is an Open Source clone of Chris Sawyer's Transport Tycoon Deluxe

Source:        %{name}-%{version}-source.tar.bz2

Requires:      fontconfig
#Requires:      libicu
#Requires:      libpng
Requires:      SDL
Requires:      zlib
BuildRequires: gcc-c++
BuildRequires: fontconfig-devel
BuildRequires: libpng-devel
BuildRequires: libicu-devel
BuildRequires: SDL-devel
BuildRequires: zlib-devel
# vendor specific dependencies
%if %{_vendor}=="alt"
Requires:      freetype
BuildRequires: freetype-devel
%endif
%if %{_vendor}=="MandrakeSoft" || %{_vendor}=="mandriva"
Requires:      freetype2
BuildRequires: libfreetype6-devel
%endif
%if %{_vendor}=="redhat" || %{_vendor}=="fedora"
Requires:      freetype
BuildRequires: freetype-devel
BuildRequires: desktop-file-utils
%endif
%if %{_vendor}=="suse"
Requires:      freetype2
BuildRequires: freetype2-devel
BuildRequires: update-desktop-files
%endif

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-buildroot

%description
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. To play the game you need to copy
the following 6 data files from your Transport Tycoon Deluxe CD to the game
data directory in %{_datadir}/games/%{name}/data:

From the Windows version of TTD you need:
sample.cat trg1r.grf trgcr.grf trghr.grf trgir.grf trgtr.grf

Or if you have the DOS version you need:
sample.cat TRG1.GRF TRGC.GRF TRGH.GRF TRGI.GRF TRGT.GRF

OpenTTD is licensed under the GNU General Public License version 2.0. For more
information, see the file 'COPYING' included with every release and source
download of the game.

%prep
%setup -q

%build
./configure \
	--revision=%{version} \
	--prefix-dir="%{_prefix}" \
	--binary-dir="bin" \
	--binary-name="%{name}" \
	--enable-debug=0 \
	--with-sdl \
	--with-zlib \
	--with-png \
	--with-freetype \
	--with-fontconfig \
	--with-icu \
	--enable-strip \
#	--menu_group="Game;" \
#	--menu-name="OpenTTD" \
#	--data-dir="share\games\%{name}" \
#	--doc-dir="share\doc\%{name}" \
#	--icon-dir="share/pixmaps" \
#	--icon-theme-dir="share/icons/hicolor" \
#	--man-dir="share/man/man6" \
#	--menu-dir="share/applications"

make %{?_smp_mflags}

%install
#rm -rf "%{buildroot}"
make install INSTALL_DIR="%{buildroot}"

# Validate menu entrys (vendor specific)
%if %{_vendor} == "redhat" || %{_vendor}=="fedora"
desktop-file-install \
	--vendor="%{_vendor}" \
	--remove-key Version \
	--dir="%{buildroot}/%{_datadir}/applications/" \
	"%{buildroot}/%{_datadir}/applications/%{name}.desktop" \
#	--delete-original
%endif
%if %{_vendor}=="suse"
%__cat > %{name}.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Name=OpenTTD
Comment=OpenTTD - A clone of the Microprose game 'Transport Tycoon Deluxe'
GenericName=OpenTTD
Type=Application
Terminal=false
Exec=%{name}
Icon=%{name}
Categories=Game;StrategyGame;
EOF
%suse_update_desktop_file -i %{name} Game StrategyGame
%endif

%clean
rm -rf "%{buildroot}"

%post
# Update the icon cache (vendor specific)
%if %{_vendor}=="MandrakeSoft" || %{_vendor}=="mandriva"
%update_icon_cache hicolor
%endif

%if %{_vendor} == "redhat" || %{_vendor}=="fedora"
touch --no-create %{_datadir}/icons/hicolor
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
	%{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi
%endif

%postun
# Update the icon cache (vendor specific)
%if %{_vendor}=="MandrakeSoft" || %{_vendor}=="mandriva"
%update_icon_cache hicolor
%endif

%if %{_vendor} == "redhat" || %{_vendor}=="fedora"
touch --no-create %{_datadir}/icons/hicolor
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
	%{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi
%endif

%files
%defattr(-, root, games, -)
%dir %{_datadir}/doc/%{name}
%dir %{_datadir}/games/%{name}
%dir %{_datadir}/games/%{name}/lang
%dir %{_datadir}/games/%{name}/data
%dir %{_datadir}/games/%{name}/gm
%dir %{_datadir}/games/%{name}/scripts
%attr(755, root, games) %{_bindir}/%{name}
%{_datadir}/doc/%{name}/*
%{_datadir}/games/%{name}/lang/*
%{_datadir}/games/%{name}/data/*
%{_datadir}/games/%{name}/scripts/*
%{_datadir}/applications/*%{name}.desktop
%{_datadir}/pixmaps/*
%{_datadir}/icons/*
%{_datadir}/icons/*/*
%{_datadir}/icons/*/*/apps
%{_datadir}/icons/*/*/apps/%{name}*
%doc %{_mandir}/man6/%{name}.6.gz

%changelog
* Thu Sep 10 2009 Marcel Gmür <ammler@openttdcoop.org> - 0.7.2

- Add openSUSE support

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

