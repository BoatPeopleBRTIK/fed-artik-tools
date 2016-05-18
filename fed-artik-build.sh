#!/bin/bash

set -e

BUILDCONFIG=~/.fed-artik-build.conf
BUILDROOT=
BUILDARCH=armv7hl
INCLUDE_ALL=
DEFINE=
SPECFILE=
CLEAN_REPOS=false

SRC_DIR=/root/rpmbuild/SOURCES
SPEC_DIR=/root/rpmbuild/SPECS
RPM_DIR=/root/rpmbuild/RPMS

pkg_src_type=
pkg_name=
pkg_version=

. `dirname "$(readlink -f "$0")"`/fed-artik-common.sh

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
	--clean-repos	Clean up repo directory before build
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
			--clean-repos)
				CLEAN_REPOS=true
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
	[ "$pkg_src_type" == "" ] && die "cannot find source type from spec"

	pkg_name=`grep '^Name:' $SPECFILE | awk '{ print $2 }'`
	[ "$pkg_name" == "" ] && die "cannot find package name from spec"

	pkg_version=`grep '^Version:' $SPECFILE | awk '{ print $2 }'`
	[ "$pkg_version" == "" ] && die "cannot find package version from spec"
	echo "1" > /dev/null
}

archive_git_source()
{
	local src_dir=$1
	if [ $INCLUDE_ALL ]; then
		uploadStash=`git stash create`
		sudo git archive --format=$pkg_src_type --prefix=$pkg_name-$pkg_version/ \
			-o $src_dir/$pkg_name-$pkg_version.$pkg_src_type ${uploadStash:-HEAD}

	else
		sudo git archive --format=$pkg_src_type --prefix=$pkg_name-$pkg_version/ \
			-o $src_dir/$pkg_name-$pkg_version.$pkg_src_type HEAD
	fi
}

setup_local_repo()
{
	local scratch_root=$1
	local local_repo=$2

	mkdir -p $local_repo

	sudo sh -c "cat > $scratch_root/etc/yum.repos.d/local.repo << __EOF__
[local]
name=Fedora-Local
baseurl=file://${local_repo}
enabled=1
gpgcheck=0
__EOF__"
}

run_rpmbuild()
{
	local scratch_root=$1
	local local_repo=$2
	local spec_base=$(basename "$SPECFILE")
	local build_cmd="rm -rf /var/cache/local*; createrepo $local_repo; dnf makecache; dnf builddep -y -v $SPEC_DIR/$spec_base; rpmbuild --target=$BUILDARCH -ba"
	if [ "$DEFINE" != "" ]; then
		build_cmd+=" --define \"$DEFINE\""
	fi
	build_cmd+=" $SPEC_DIR/$spec_base"

	sudo $SCRIPT_DIR/chroot_fedora.sh -b $local_repo $scratch_root "$build_cmd"
}

copy_output_rpms()
{
	local scratch_root=$1
	local local_repo=$2
	local build_arch=$3

	sudo sh -c "cp -f $scratch_root/$RPM_DIR/$build_arch/*.rpm $local_repo"
	sudo sh -c "chown $user:$user $local_repo/*"
}

detect_spec_file()
{
	SPECFILE=`find ./packaging -name "*.spec"`
	[ -e $SPECFILE ] || die "not found spec file"
}

eval BUILDROOT=$BUILDROOT
detect_spec_file
parse_config $BUILDCONFIG
parse_options "$@"

eval BUILDROOT=$BUILDROOT
SCRATCH_ROOT=$BUILDROOT/BUILDROOT
LOCAL_REPO=$BUILDROOT/repos/$FEDORA_VER/$BUILDARCH/RPMS

if $CLEAN_REPOS ; then
	rm -rf $LOCAL_REPO/*
fi

parse_pkg_info
archive_git_source $SCRATCH_ROOT/$SRC_DIR

sudo cp -f `readlink -e $SPECFILE` $SCRATCH_ROOT/$SPEC_DIR

setup_local_repo $SCRATCH_ROOT $LOCAL_REPO
run_rpmbuild $SCRATCH_ROOT $LOCAL_REPO
copy_output_rpms $SCRATCH_ROOT $LOCAL_REPO $BUILDARCH

echo "Build is done. Please find your rpm from " $LOCAL_REPO
