#!/bin/sh -e
#
#  Copyright 2021, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.sh 292 2023-12-27 22:45:41Z rhubarb-geek-nz $
#

THIS="$0"
APPNAME=usign-openwrt
VERSION=2020-05-23
SVNVERS=$(git log --oneline "$THIS" | wc -l)

trap "rm -rf usign-git data rpm.dir rpm.spec" 0

git clone https://git.openwrt.org/project/usign.git usign-git

(
	set -e

	cd usign-git

	git checkout f1f65026a94137c91b5466b149ef3ea3f20091e9

	mkdir build
	cd build
	cmake ..
	make
	strip usign
)

RELEASE=$( cd usign-git ; git rev-parse --short HEAD )-$( echo $SVNVERS )

mkdir -p data/usr/bin

cp usign-git/build/usign "data/usr/bin/$APPNAME"

SIZE=$(du -sk data/usr/bin/$APPNAME | while read A B; do echo $A; break; done)

if dpkg --print-architecture 2>/dev/null
then
	DPKGARCH=$(dpkg --print-architecture)
	mkdir -p data/DEBIAN 
	cat > data/DEBIAN/control <<EOF
Package: $APPNAME
Version: $VERSION-$RELEASE
Architecture: $DPKGARCH
Maintainer: rhubarb-geek-nz@users.sourceforge.net
Section: misc
Priority: extra
Installed-Size: $SIZE
Description: OpenWrt signature verification utility
EOF

	dpkg-deb --root-owner-group --build data "$APPNAME"_"$VERSION-$RELEASE"_"$DPKGARCH".deb

	rm -rf data/DEBIAN 
fi

if rpmbuild --version 2>/dev/null
then
	(
		VERSION=$( echo $VERSION | sed y/-/./ )
		RELEASE=$( echo $RELEASE | sed y/-/./ )
		cat > rpm.spec << EOF
Summary: OpenWrt signature verification utility
Name: $APPNAME
Version: $VERSION
Release: $RELEASE
License: AS IS
Prefix: /

%description
	Tiny signify replacement

%files
%defattr(-,root,root)
/usr/bin/$APPNAME

%clean
echo clean "$\@"

EOF
		mkdir rpm.dir

		rpmbuild --buildroot "$(pwd)/data" --define "_build_id_links none" --define "_rpmdir $(pwd)/rpm.dir" -bb "$(pwd)/rpm.spec"

		find rpm.dir -type f -name "*.rpm" | while read N
		do
			basename "$N"
			rpm -qlvp "$N"
			mv "$N" .
		done
	)
fi
