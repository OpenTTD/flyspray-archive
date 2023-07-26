# $Id$
#-------------------------------------------------------------------------------
# spec file for the openttd rpm package
#
# Copyright (c) 2007-2009 The OpenTTD developers
#
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself
#
#-------------------------------------------------------------------------------

%define dedicated       0
# We nneed 3 rows space
# so project diffs can apply also if the 
# version changes
%define branch
%define binname         openttd
%define mainver         1.0
%define subver          RC1
%define srcver          %{mainver}.0-%{subver}

%if %{dedicated}
Name:           %{binname}-dedicated
%else
Name:           %{binname}
%endif
Version:        %{mainver}.%{subver}
Release:        1%{?dist}
Group:          Amusements/Games
License:        GPLv2
URL:            http://www.openttd.org
Summary:        OpenTTD is an Open Source clone of Chris Sawyer's Transport Tycoon Deluxe

Source:         openttd%{?branch:-%{branch}}-%{srcver}-source.tar.bz2

# the main package works with the exact same data package version only
Requires:       %{binname}-data = %{version}
BuildRequires:  gcc-c++
BuildRequires:  libpng-devel
BuildRequires:  zlib-devel
%if 0%{?mandriva_version}
BuildRequires:  liblzo-devel                                          
%else 
 %if 0%{?suse_version} == 910
BuildRequires:  lzo2-devel
 %else
BuildRequires:  lzo-devel                                         
 %endif
%endif

# Desktop specific tags, not needed for dedicated
%if !%{dedicated}
Patch0:         desktop-fix.diff

BuildRequires:  fontconfig-devel
BuildRequires:  SDL-devel

# vendor specific dependencies
 %if 0%{?rhel_version} < 400 || 0%{?rhel_version} > 500
BuildRequires:  libicu-devel
 %endif
 %if %{_vendor}=="redhat" || %{_vendor}=="fedora"
BuildRequires:  freetype-devel
 %endif
 %if %{_vendor}=="suse" || %{_vendor}=="mandriva"
BuildRequires:  freetype2-devel
 %endif
 %if 0%{?suse_version}
BuildRequires:  update-desktop-files
 %endif
%endif

%if %{dedicated}
Conflicts:      %{binname} %{binname}-gui
Requires:       openttd-data-nosound
%else
Provides:       %{binname}-gui
Conflicts:      %{binname}-dedicated
Requires:       openttd-data-opensfx
# recommends works for suse (not sles9) and mandriva, only
 %if 0%{?suse_version} > 910  || 0%{?mdkversion}
Recommends:     openttd-data-openmsx
 %endif
%endif
Requires:       openttd-data-opengfx

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot

%description
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. To play the game you need either 
the original data from the game or install the recommend packages OpenGFX,
OpenSFX and maybe some music from tt-forums.net.

OpenTTD is licensed under the GNU General Public License version 2.0. For more
information, see the file 'COPYING' included with every release and source
download of the game.

# the subpackage data needs only to build once, the dedicated version
# can reuse the data package of the gui package
%if !%{dedicated}
%package data
Summary:        Data package for OpenTTD
Group:          Amusements/Games
 %if 0%{?suse_version} >= 1120 || 0%{?fedora} || 0%{?mdkversion} 
BuildArch:      noarch 
 %endif

%description data
OpenTTD is a reimplementation of the Microprose game "Transport Tycoon Deluxe"
with lots of new features and enhancements. To play the game you need either
the original data from the game or the required package OpenGFX and OpenSFX.

This package is required by openttd gui and openttd dedicated package. This 
way it is possible to install a openttd version without SDL requirement.

%endif

%prep
%setup -qn openttd%{?branch:-%{branch}}-%{srcver} 
%if !%{dedicated}
%patch0
%endif

%build
# Note: for (at least) CentOS '#' comments end '\' continue command on new line.
#       So place all '#' commented parameters at the end
./configure \
        --prefix-dir="%{_prefix}" \
        --binary-name="%{binname}" \
        --enable-strip \
        --binary-dir="bin" \
        --data-dir="share/%{binname}" \
        --doc-dir="share/doc/%{binname}" \
        --menu-name="OpenTTD%{?branch: %{branch}}" \
        --menu-group="Game;StrategyGame;" \
        --enable-dedicated="%{dedicated}" \
        --revision="%{srcver}" \
#       --with-makedepend="%{do_makedepend}" \
#       --enable-debug=0 \
#       --with-sdl \
#       --with-zlib \
#       --with-png \
#       --with-freetype \
#       --with-fontconfig \
#       --with-icu \
#       --doc-dir="share\doc\%{name}" \
#       --icon-dir="share/pixmaps" \
#       --icon-theme-dir="share/icons/hicolor" \
#       --man-dir="share/man/man6" \
#       --menu-dir="share/applications"

make %{?_smp_mflags}

%install
%if %{dedicated}
# dedicated package needs binary only
install -D -m0755 bin/openttd %{buildroot}/%{_bindir}/%{binname}
%else
make install INSTALL_DIR="%{buildroot}"
 %if 0%{?suse_version}
%suse_update_desktop_file -r %{binname} Game StrategyGame
 %endif
%endif

%clean
rm -rf "%{buildroot}"

%files
%attr(755, root, root) %{_bindir}/%{binname}

# all other files are for the gui version only, also no
# subpackage needed for the dedicated version
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
%dir %{_datadir}/icons/hicolor/256x256
%dir %{_datadir}/icons/hicolor/256x256/apps
%{_datadir}/applications/%{binname}.desktop
%{_datadir}/icons/hicolor/16x16/apps/%{binname}.png
%{_datadir}/icons/hicolor/32x32/apps/%{binname}.png
%{_datadir}/icons/hicolor/48x48/apps/%{binname}.png
%{_datadir}/icons/hicolor/64x64/apps/%{binname}.png
%{_datadir}/icons/hicolor/128x128/apps/%{binname}.png
%{_datadir}/icons/hicolor/256x256/apps/%{binname}.png
%{_datadir}/pixmaps/%{binname}.32.xpm

%files data
%defattr(-, root, root)
%dir %{_datadir}/doc/%{binname}
%dir %{_datadir}/%{binname}
%dir %{_datadir}/%{binname}/lang
%dir %{_datadir}/%{binname}/data
%dir %{_datadir}/%{binname}/gm
%dir %{_datadir}/%{binname}/scripts
%dir %{_datadir}/%{binname}/ai
%{_datadir}/doc/%{binname}/*
%{_datadir}/%{binname}/lang/*
%{_datadir}/%{binname}/data/*
%{_datadir}/%{binname}/scripts/*
%{_datadir}/%{binname}/ai/*
%{_datadir}/%{binname}/gm/*
%doc %{_mandir}/man6/%{binname}.6.*

%endif

%changelog
