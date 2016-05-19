#!/bin/bash

set -e

BUILDCONFIG=~/.fed-artik-build.conf
BUILDROOT=
OUTPUT_DIR=`pwd`/fed_artik_output
COPY_DIR=
KS_FILE=

CHROOT_OUTPUT_DIR=/root/fed_artik_output

. `dirname "$(readlink -f "$0")"`/fed-artik-common.sh

usage() {
	cat <<EOF
	usage: ${0##*/} [options] kickstart

	-h              Print this help message
	-B BUILDROOT	BUILDROOT directory, if not specified read from ~/.fed-artik-build.conf
	-o OUTPUT_DIR	Output directory
	--copy-dir	Copy directory under kickstart file
	--ks-file KS	Kickstart file
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
			-o)
				OUTPUT_DIR=`readlink -m "$2"`
				[ ! -d $OUTPUT_DIR ] && mkdir -p $OUTPUT_DIR
				shift ;;
			--copy-dir)
				COPY_DIR="$2"
				shift ;;
			--ks-file)
				KS_FILE="$2"
				shift ;;
			*)
				shift ;;
		esac
	done
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

prepare_creator_directory()
{
	local scratch_root=$1
	local chroot_output_dir=$2
	local ks_file=$3
	local copy_dir=$4
	local local_repo=$5

	local out_dir=$scratch_root/$chroot_output_dir

	local ks_base=$(basename "$ks_file")

	sudo sh -c "mkdir -p $out_dir"
	sudo sh -c "rm -rf $out_dir/*"
	sudo sh -c "cp -f $SCRIPT_DIR/run_appliance_creator.sh $out_dir/"

	sudo sh -c "cp -f $ks_file $out_dir"
	sudo sed -i "/\%package/i repo --name=local --baseurl=file:\/\/${local_repo} --cost=1" $out_dir/$ks_base

	if [ "$copy_dir" != "" ]; then
		sudo sh -c "cp -rf $copy_dir $out_dir"
	fi
}

copy_creator_rpm()
{
	local script_dir=$1
	local local_repo=$2

	cp $script_dir/livecd-tools*.rpm $local_repo
	cp $script_dir/appliance-tools*.rpm $local_repo
}

run_creator()
{
	local scratch_root=$1
	local local_repo=$2
	local ks_file=$3
	local ks_name=$4
	local chroot_output_dir=$5

	local build_cmd="rm -rf /var/cache/local*; createrepo $local_repo; dnf makecache; "
	local build_cmd+="cd $chroot_output_dir; ./run_appliance_creator.sh $ks_file $chroot_output_dir $ks_name $FEDORA_VER"

	sudo $SCRIPT_DIR/chroot_fedora.sh -b $local_repo $scratch_root "$build_cmd"
}

copy_output_file()
{
	local scratch_root=$1
	local output_dir=$2
	local chroot_output_dir=$3
	local ks_name=$4

	local disk_file=$scratch_root/$chroot_output_dir/$ks_name/$ks_name-sda.raw
	local output_name=$ks_name-rootfs-`date +"%Y%m%d%H%M%S"`.tar

	sudo sh -c "guestfish << _EOF_
add $disk_file
run
mount /dev/sda1 /
tar-out / $output_dir/$output_name
_EOF_
"
	gzip $output_dir/$output_name

	echo "Clean up chroot build directory..."
	sudo sh -c "rm -rf $scratch_root/$chroot_output_dir"

	ls -l $output_dir/$output_name.gz
}

eval BUILDROOT=$BUILDROOT
parse_config $BUILDCONFIG
parse_options "$@"

eval BUILDROOT=$BUILDROOT
SCRATCH_ROOT=$BUILDROOT/BUILDROOT
LOCAL_REPO=$BUILDROOT/repos/$FEDORA_VER/$BUILDARCH/RPMS

[ ! -d $OUTPUT_DIR ] && mkdir -p $OUTPUT_DIR
if [ "$KS_FILE" == "" ] || [ ! -e $KS_FILE ]; then
	die "cannot find kickstart file"
fi

KS_BASE=$(basename "$KS_FILE")
KS_NAME=${KS_BASE%.*}

setup_local_repo $SCRATCH_ROOT $LOCAL_REPO
copy_creator_rpm $SCRIPT_DIR $LOCAL_REPO
prepare_creator_directory $SCRATCH_ROOT $CHROOT_OUTPUT_DIR $KS_FILE $COPY_DIR $LOCAL_REPO
run_creator $SCRATCH_ROOT $LOCAL_REPO $KS_BASE $KS_NAME $CHROOT_OUTPUT_DIR
copy_output_file $SCRATCH_ROOT $OUTPUT_DIR $CHROOT_OUTPUT_DIR $KS_NAME