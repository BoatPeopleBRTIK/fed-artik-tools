#!/bin/bash

FEDORA_VER=f22
BUILDARCH=armv7hl
USE_OFFICIAL_REPO=false
BUILDROOT=
EXECUTE_COMMANDS=""
ESSENTIAL_PACKAGES="@development-tools fedora-packager rpmdevtools dnf-plugins-core"

SCRIPT_DIR=`dirname "$(readlink -f "$0")"`
if [ $SUDO_USER ]; then user=$SUDO_USER; else user=`whoami`; fi

usage() {
	cat <<EOF
	usage: ${0##*/} [options]

	-h              Print this help message
	-B BUILDROOT	BUILDROOT directory, if not specified read from ~/.fed-artik-build.conf
	-A ARCH		Build Architecture. armv7hl
	-f Fedora_Ver	Fedora version(Default: f22)
	--official-repo	Use official repository instead of meta repository
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
				BUILDROOT="$2"
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
			*)
				shift ;;
		esac
	done
}

change_official_repo()
{
	return
}

append_command()
{
	EXECUTE_COMMANDS+="${1};"
}

insert_command()
{
	EXECUTE_COMMANDS="${@}; ${EXECUTE_COMMANDS}"
}

install_essential_packages()
{
	append_command "dnf install $ESSENTIAL_PACKAGES;"
}

setup_initial_directory()
{
	append_command "rpmdev-setuptree"
}

parse_options "$@"

if [ $USE_OFFICIAL_REPO ]; then
	change_official_repo
fi

install_essential_packages
setup_initial_directory

$SCRIPT_DIR/chroot_fedora.sh $BUILDROOT $EXECUTE_COMMANDS
