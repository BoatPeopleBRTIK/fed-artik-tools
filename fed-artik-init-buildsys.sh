#!/bin/bash

BUILDCONFIG=~/.fed-artik-build.conf
FEDORA_VER=f22
BUILDARCH=armv7hl
USE_OFFICIAL_REPO=false
BUILDROOT=
EXECUTE_COMMANDS=""
ESSENTIAL_PACKAGES="@development-tools fedora-packager rpmdevtools dnf-plugins-core distcc"
USE_DISTCC=false
IMPORT_ROOTFS=

. fed-artik-common.sh

usage() {
	cat <<EOF
	usage: ${0##*/} [options]

	-h              Print this help message
	-B BUILDROOT	BUILDROOT directory, if not specified read from ~/.fed-artik-build.conf
	-A ARCH		Build Architecture. armv7hl
	-f Fedora_Ver	Fedora version(Default: f22)
	--official-repo	Use official repository instead of meta repository
	--distcc	Use distcc to accelerate build
	-I ROOTFS	Import fedora rootfs
EOF
	exit 0
}

parse_options()
{
	for opt in "$@"
	do
		case "$opt" in
			-h|--help)
				usage
				shift ;;
			-B|--buildroot)
				BUILDROOT=`readlink -e "$2"`
				shift ;;
			-A|--arch)
				BUILDARCH="$2"
				shift ;;
			-f)
				FEDORA_VER="$2"
				shift ;;
			--official-repo)
				USE_OFFICIAL_REPO=true
				shift ;;
			-I)
				IMPORT_ROOTFS="$2"
				shift ;;
			*)
				shift ;;
		esac
	done
}

change_official_repo()
{
	local scratch_root=$1
	sudo sed -i 's/^metalink/#metalink/g' $scratch_root/etc/yum.repos.d/fedora*
	[ -d $scratch_root/etc/yum.repos.d/rpmfusion* ] && \
		sudo sed -i 's/^mirrorlist/#mirrorlist/g' $scratch_root/etc/yum.repos.d/rpmfusion*
	sudo sed -i 's/^#baseurl/baseurl/g' $scratch_root/etc/yum.repos.d/*
}

install_essential_packages()
{
	append_command "dnf install -q -y $ESSENTIAL_PACKAGES"
}

setup_initial_directory()
{
	append_command "rpmdev-setuptree"
}

setup_distcc()
{
	append_command "cd /usr/local/bin; for f in gcc g++ cc c++ armv7hl-redhat-linux-gnueabi-gcc; do ln -sf /usr/bin/distcc \$f; done"
	append_command "echo 127.0.0.1 > /etc/distcc/hosts"
}

parse_config $BUILDCONFIG
parse_options "$@"

eval BUILDROOT=$BUILDROOT
SCRATCH_ROOT=$BUILDROOT/BUILDROOT
[ ! -d $SCRATCH_ROOT ] && die "cannot find buildroot"

if [ "$IMPORT_ROOTFS" != "" ]; then
	sudo rm -rf $SCRATCH_ROOT/*
	sudo tar xf $IMPORT_ROOTFS -C $SCRATCH_ROOT
fi

if [ "$USE_OFFICIAL_REPO" == "1" ]; then
	change_official_repo $SCRATCH_ROOT
fi

install_essential_packages
setup_initial_directory
[ $USE_DISTCC ] && setup_distcc

echo "### You may need to wait long time(>5 minutes) to synchronize rpmdb"
sudo $SCRIPT_DIR/chroot_fedora.sh $SCRATCH_ROOT "$EXECUTE_COMMANDS"
