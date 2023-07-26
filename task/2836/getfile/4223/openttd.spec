# Copyright (c) 2006-2009 oc2pus
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments to toni@links2linux.de

# norootforbuild

%define _prefix	/usr
%define _ver2	0.7.0

Summary:		OpenTTD is a clone of the Microprose game "Transport Tycoon Deluxe"
Name:			openttd
Version:		%{_ver2}
Release:		111.pm.1
License:		GPL
Group:			Amusements/Games/Strategy/Turn Based
URL:			http://www.openttd.org/index.php
Source:			http://binaries.openttd.org/releases/0.7.0/openttd-0.7.0-source.tar.bz2
Source1:		%{name}-0.5.0-scenarios.tar.bz2
Source90:		%{name}-rpmlintrc
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root
BuildRequires:	fontconfig-devel fontconfig
BuildRequires:	freetype2-devel
BuildRequires:	gcc-c++
BuildRequires:	hicolor-icon-theme
BuildRequires:	libicu-devel
BuildRequires:	libpng-devel >= 1.2.5
BuildRequires:	pkgconfig
BuildRequires:	SDL-devel >= 1.2.7
BuildRequires:	update-desktop-files
BuildRequires:	zlib-devel
#Requires:		hicolor-icon-theme

%description
OpenTTD is a clone of the Microprose game 'Transport Tycoon Deluxe',
a popular game originally written by Chris Sawyer. It attempts to
mimic the original game as closely as possible while extending it
with new features.

OpenTTD is licensed under the GNU General Public License version 2.0.

Notice:
OpenTTD requires the original version of Transport Tycoon Deluxe
data files in order to function. Please refer to the readme for
more information.

You have to MANUALLY copy them to the game data directory!

%debug_package

%prep
%setup -q -n %{name}-%{_ver2}
#%setup -q -n %{name}-0.7.0-RC2

%__rm docs/OSX_*
%__rm docs/Readme_OS2*
%__rm docs/Readme_Windows*

%build
./configure \
	--os=UNIX \
	--prefix-dir=%{_prefix} \
	--binary-dir=bin \
	--data-dir=share/%{name} \
	--icon-dir=share/pixmaps \
	--install-dir=%{buildroot} \
	--with-sdl \
	--with-zlib \
	--with-png \
	--with-freetype \
	--with-fontconfig
#	--with-midi
%__make %{?jobs:-j%{jobs}}

%install
%__make install

%__install -dm 755 %{buildroot}%{_datadir}/%{name}/scenario
pushd %{buildroot}%{_datadir}/%{name}/scenario
	%__tar xfj %{SOURCE1}
popd

%__install -dm 755 %{buildroot}%{_mandir}/man6
%__install -m 644 docs/%{name}.6 \
	%{buildroot}%{_mandir}/man6

# icon
%__install -dm 755 %{buildroot}%{_datadir}/pixmaps
%__install -m 644 media/openttd.48.png \
	%{buildroot}%{_datadir}/pixmaps/%{name}.png

# menu-entry
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

# done with doc-macro
%__rm -r %{buildroot}%{_datadir}/doc/%{name}

%clean
[ -d "%{buildroot}" -a "%{buildroot}" != "" ] && %__rm -rf "%{buildroot}"

%files
%defattr(-, root, root)
%doc COPYING *.txt
%doc docs/*
%doc %{_mandir}/man6/*
%{_bindir}/%{name}
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/*
%{_datadir}/pixmaps/*
%{_datadir}/applications/%{name}*.desktop
%{_datadir}/icons/*/*/apps/%{name}*

%changelog
* Wed Apr 01 2009 Toni Graffy <toni@links2linux.de> - 0.7.0-111.pm.1
- update to 0.7.0
* Fri Mar 27 2009 Toni Graffy <toni@links2linux.de> - 0.7.0RC2-111.pm.1
- update to 0.7.0RC2
* Sun Mar 15 2009 Toni Graffy <toni@links2linux.de> - 0.7.0RC1-111.pm.1
- update to 0.7.0RC1
* Wed Oct 01 2008 Toni Graffy <toni@links2linux.de> - 0.6.3-111.pm.1
- update to 0.6.3
* Tue Sep 23 2008 Toni Graffy <toni@links2linux.de> - 0.6.3RC1-111.pm.1
- update to 0.6.3RC1
* Sat Aug 02 2008 Toni Graffy <toni@links2linux.de> - 0.6.2-111.pm.1
- update to 0.6.2
* Wed Jul 30 2008 Toni Graffy <toni@links2linux.de> - 0.6.2RC2-111.pm.1
- update to 0.6.2RC2
* Thu Jul 17 2008 Toni Graffy <toni@links2linux.de> - 0.6.2RC1-111.pm.1
- update to 0.6.2RC1
* Sun Jun 01 2008 Toni Graffy <toni@links2linux.de> - 0.6.1-111.pm.1
- update to 0.6.1
* Tue May 27 2008 Toni Graffy <toni@links2linux.de> - 0.6.1RC2-111.pm.1
- update to 0.6.1RC2
* Sat May 03 2008 Toni Graffy <toni@links2linux.de> - 0.6.1RC1-111.pm.1
- update to 0.6.1RC1
* Tue Apr 01 2008 Toni Graffy <toni@links2linux.de> - 0.6.0-111.pm.1
- update to 0.6.0
* Thu Mar 27 2008 Toni Graffy <toni@links2linux.de> - 0.6.0RC1-111.pm.1
- update to 0.6.0RC1
* Tue Mar 04 2008 Toni Graffy <toni@links2linux.de> - 0.6.0beta5-111.pm.1
- update to 0.6.0beta5
* Tue Feb 19 2008 Toni Graffy <toni@links2linux.de> - 0.6.0beta4-111.pm.1
- update to 0.6.0beta4
* Tue Jan 22 2008 Toni Graffy <toni@links2linux.de> - 0.6.0beta3-111.pm.1
- update to 0.6.0beta3
* Thu Dec 13 2007 Toni Graffy <toni@links2linux.de> - 0.6.0beta2-111.pm.1
- update to 0.6.0beta2
* Wed Sep 19 2007 Toni Graffy <toni@links2linux.de> - 0.5.3-111.pm.1
- update to 0.5.3
* Sat Sep 01 2007 Toni Graffy <toni@links2linux.de> - 0.5.3rc3-45.pm.1
- update to 0.5.3rc3
* Sun Jul 08 2007 Toni Graffy <toni@links2linux.de> - 0.5.3rc2-44.pm.1
- update to 0.5.3rc2
* Thu Jun 28 2007 Toni Graffy <toni@links2linux.de> - 0.5.3rc1-42.pm.1
- update to 0.5.3rc1
* Tue May 29 2007 Toni Graffy <toni@links2linux.de> - 0.5.2-0.pm.1
- update to 0.5.2
* Thu May 17 2007 Toni Graffy <toni@links2linux.de> - 0.5.2rc1-0.pm.1
- update to 0.5.2rc1
* Sat Apr 21 2007 Toni Graffy <toni@links2linux.de> - 0.5.1-0.pm.1
- update to 0.5.1
* Wed Apr 18 2007 Toni Graffy <toni@links2linux.de> - 0.5.1rc3-0.pm.1
- update to 0.5.1rc3
* Sat Mar 24 2007 Toni Graffy <toni@links2linux.de> - 0.5.1rc2-0.pm.1
- update to 0.5.1rc2
* Wed Mar 21 2007 Toni Graffy <toni@links2linux.de> - 0.5.1rc1-0.pm.1
- update to 0.5.1rc1
* Wed Feb 28 2007 Toni Graffy <toni@links2linux.de> - 0.5.0-0.pm.1
- update to 0.5.0
* Thu Feb 08 2007 Toni Graffy <toni@links2linux.de> - 0.5.0rc5-0.pm.1
- update to 0.5.0rc5
* Thu Jan 18 2007 Toni Graffy <toni@links2linux.de> - 0.5.0rc4-0.pm.1
- update to 0.5.0rc4
* Sun Jan 07 2007 Toni Graffy <toni@links2linux.de> - 0.5.0rc3-0.pm.1
- update to 0.5.0rc3
* Sun Dec 31 2006 Toni Graffy <toni@links2linux.de> - 0.5.0rc2-0.pm.1
- update to 0.5.0rc2
* Fri Dec 22 2006 Toni Graffy <toni@links2linux.de> - 0.5.0rc1-0.pm.1
- update to 0.5.0rc1
- fixed Menu-Entry
* Fri Oct 27 2006 Toni Graffy <toni@links2linux.de> - 0.4.8-0.pm.1
- Initial RPM release 0.4.8
