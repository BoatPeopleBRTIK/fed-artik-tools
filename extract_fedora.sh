#!/bin/bash

IMG_NAME=$1
TARGET_DIR=$2

print_usage()
{
	echo "$0 [image_name] [target_dir]"
	echo "Ex) $0 artik10_sdfuse.img fedora_root"
	exit 0
}

package_check()
{
	command -v $1 >/dev/null 2>&1 || { echo >&2 "${1} not installed. Aborting."; exit 1; }
}

package_check guestfish

if [ "$IMG_NAME" == "" ] || [ "$TARGET_DIR" == "" ]; then
	print_usage
fi

[ -e $IMG_NAME ] || print_usage

sudo ls > /dev/null 2>&1

sudo guestfish << _EOF_
add $1
run
mount /dev/sda3 /
copy-out /rootfs.tar.gz .
_EOF_

[ -d $TARGET_DIR ] || mkdir -p $TARGET_DIR

sudo tar xf rootfs.tar.gz -C $TARGET_DIR
