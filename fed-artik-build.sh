#!/bin/bash

set -x

BUILDROOT=
BUILDARCH=armv7hl
INCLUDE_ALL=
DEFINE=
SPECFILE=

SRC_DIR=/root/rpmbuild/SOURCES
SPEC_DIR=/root/rpmbuild/SPECS
RPM_DIR=/root/rpmbuild/RPMS

SCRIPT_DIR=`dirname "$(readlink -f "$0")"`
if [ $SUDO_USER ]; then user=$SUDO_USER; else user=`whoami`; fi

pkg_src_type=
pkg_name=
pkg_version=

out() { printf "$1 $2\n" "${@:3}"; }
error() { out "==> ERROR:" "$@"; } >&2
msg() { out "==>" "$@"; }
msg2() { out "  ->" "$@";}
die() { error "$@"; exit 1; }

usage() {
	cat <<EOF
	usage: ${0##*/} [options]

	-h              Print this help message
	-B BUILDROOT	BUILDROOT directory, if not specified read from ~/.fed-artik-build.conf
	-A ARCH		Build Architecture. armv7hl
	--include-all	uncommitted changes and untracked files would be
	                included while generating tar ball
	--define DEFINE	define macro X with value Y with format "X Y"
	--spec SPECFILE	specify a spec file to use. It should be a file name
	                that this tool will find it in packaging dir
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
				[ ! -d $BUILDROOT ] && die "cannot find buildroot"
				shift ;;
			-A|--arch)
				BUILDARCH="$2"
				shift ;;
			--include-all)
				INCLUDE_ALL=true
				shift ;;
			--define)
				DEFINE="$2"
				shift ;;
			--spec)
				SPECFILE="$2"
				shift ;;
			*)
				shift ;;
		esac
	done
}

parse_source_type()
{
	local __src_type=$1
	SOURCE_TYPE="tar.gz tar.bz2 tar.xz"

	for _type in $SOURCE_TYPE
	do
		result=`grep "^Source[0-9]:\|^Source:" $SPECFILE | grep "$_type"`
		if [ "$result" != "" ]; then
			eval $__src_type=$_type
			break
		fi
	done
}

parse_pkg_info()
{
	parse_source_type pkg_src_type
	[ -z $pkg_src_type ] && die "cannot find source type from spec"

	pkg_name=`grep '^Name:' $SPECFILE | awk '{ print $2 }'`
	[ -z $pkg_name ] && die "cannot fine package name from spec"

	pkg_version=`grep '^Version:' $SPECFILE | awk '{ print $2 }'`
	[ -z $pkg_version ] && die "cannot fine package version from spec"
}

archive_git_source()
{
	local src_dir=$1
	if [ $INCLUDE_ALL ]; then
		uploadStash=`git stash create`
		git archive --format=$pkg_src_type --prefix=$pkg_name-$pkg_version/ \
			-o $src_dir/$pkg_name-$pkg_version.$pkg_src_type ${uploadStash:-HEAD}

	else
		git archive --format=$pkg_src_type --prefix=$pkg_name-$pkg_version/ \
			-o $src_dir/$pkg_name-$pkg_version.$pkg_src_type HEAD
	fi
}

run_rpmbuild()
{
	local spec_base=$(basename "$SPECFILE")
	local build_cmd="dnf builddep -y -q $SPEC_DIR/$spec_base; rpmbuild --target=$BUILDARCH -ba"
	if [ "$DEFINE" != "" ]; then
		build_cmd+=" --define \"$DEFINE\""
	fi
	build_cmd+=" $SPEC_DIR/$spec_base"

	$SCRIPT_DIR/chroot_fedora.sh $BUILDROOT "$build_cmd"
}

parse_options "$@"
parse_pkg_info
archive_git_source $BUILDROOT/$SRC_DIR

cp -f `readlink -e $SPECFILE` $BUILDROOT/$SPEC_DIR

run_rpmbuild