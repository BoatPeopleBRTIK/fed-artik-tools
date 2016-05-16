#!/bin/bash

BUILDCONFIG=.fed-artik-build.conf

. fed-artik-common.sh

usage() {
	cat <<EOF
	usage: ${0##*/} [options]

	-h              Print this help message
	-B BUILDROOT	BUILDROOT directory, if not specified read from ~/FED-ARTIK-ROOT
	-C conf		Build configurations(If not specified, use default .fed-artik-build.conf
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
			-C)
				BUILDCONFIG="$2"
				shift ;;
			-I)
				IMPORT_ROOTFS="$2"
				shift ;;
			*)
				shift ;;
		esac
	done
}

make_initial_directories()
{
	local root_dir=$1
	local repo_name=$2
	local repo_arch=$3

	mkdir -p $root_dir
	mkdir -p $root_dir/BUILDROOT
	mkdir -p $root_dir/repos/$repo_name/$repo_arch/{RPMS,SRPMS}
}

parse_config $BUILDCONFIG
parse_options $@

eval BUILDROOT=$BUILDROOT
SCRATCH_ROOT=$BUILDROOT/BUILDROOT

cp -f .fed-artik-build.conf ~/
make_initial_directories $BUILDROOT $FEDORA_VER $BUILDARCH

if [ "$IMPORT_ROOTFS" != "" ]; then
	sudo rm -rf $SCRATCH_ROOT/*
	sudo tar xf $IMPORT_ROOTFS -C $SCRATCH_ROOT
fi

