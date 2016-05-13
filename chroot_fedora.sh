#!/bin/bash

BIND_MOUNTS=(
)
PRE_CHROOT_CMD=
POST_CHROOT_CMD=
USER=
EXECUTE_COMMANDS=""

out() { printf "$1 $2\n" "${@:3}"; }
error() { out "==> ERROR:" "$@"; } >&2
msg() { out "==>" "$@"; }
msg2() { out "  ->" "$@";}
die() { error "$@"; exit 1; }

usage() {
	cat <<EOF
	usage: ${0##*/} chroot-dir [options] [command]

	-h              Print this help message
	-b [directory]	Specify bind mount directory
	-s [script]	Specify host script before chroot
	-r [script]	Specify host script after chroot
	-u [user]	Login to user

	If 'command' is unspecified, ${0##*/} will launch /bin/sh.

EOF
}

append_command()
{
	EXECUTE_COMMANDS+="${1};"
}

insert_command()
{
	EXECUTE_COMMANDS="${@}; ${EXECUTE_COMMANDS}"
}

function parse_args()
{
	local opts=`getopt -o "hb:s:r:u:" -- "$@"`
	eval set -- "$opts"

	while true; do
		case "$1" in
			-h ) usage; exit 0 ;;
			-b ) BIND_MOUNTS=("$2" "${BIND_MOUNTS[@]}"); shift 2 ;;
			-s ) PRE_CHROOT_CMD=$2; shift 2 ;;
			-r ) POST_CHROOT_CMD=$2; shift 2 ;;
			-u ) USER=$2; shift 2;;
			-- )
				chrootdir=$2;
				if [ "$3" != "" ]; then
					append_command $3
				fi
				break
		esac
	done
}

chroot_add_mount() {
	mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_maybe_add_mount() {
	local cond=$1; shift
	if eval "$cond"; then
		chroot_add_mount "$@"
	fi
}

qemu_arm_setup() {
	[ -e $1/usr/bin/qemu-arm-static ] || cp /usr/bin/qemu-arm-static $1/usr/bin
	[ -e cpuinfo.lie ] || cat > cpuinfo.lie << __EOF__
processor   : 0
model name  : ARMv7 Processor rev 1 (v7l)
BogoMIPS    : 125.00
Features    : half thumb fastmult vfp edsp thumbee neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae evtstrm
CPU implementer : 0x41
CPU architecture: 7
CPU variant : 0x2
CPU part    : 0xc0f
CPU revision    : 1
Hardware    : ARM-Versatile Express
Revision    : 0000
Serial      : 0000000000000000
__EOF__
	chroot_add_mount cpuinfo.lie "$1/proc/cpuinfo" -o rbind

	echo "Disable sslverify option of fedora"
	grep -q 'sslverify' $1/etc/dnf/dnf.conf || echo "sslverify=False" >> $1/etc/dnf/dnf.conf
}

chroot_setup() {
	CHROOT_ACTIVE_MOUNTS=()
	[[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existing EXIT trap'
	trap 'chroot_teardown' EXIT

	chroot_maybe_add_mount "! mountpoint -q '$1'" "$1" "$1" --bind &&
		chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
		chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
		chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
		chroot_add_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
		chroot_add_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
		chroot_add_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
		chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

chroot_teardown() {
	umount "${CHROOT_ACTIVE_MOUNTS[@]}"
	unset CHROOT_ACTIVE_MOUNTS
}

chroot_add_resolv_conf() {
	local chrootdir=$1 resolv_conf=$1/etc/resolv.conf

	# Handle resolv.conf as a symlink to somewhere else.
	if [[ -L $chrootdir/etc/resolv.conf ]]; then
		# readlink(1) should always give us *something* since we know at this point
		# it's a symlink. For simplicity, ignore the case of nested symlinks.
		resolv_conf=$(readlink "$chrootdir/etc/resolv.conf")
		if [[ $resolv_conf = /* ]]; then
			resolv_conf=$chrootdir$resolv_conf
		else
			resolv_conf=$chrootdir/etc/$resolv_conf
		fi

		# ensure file exists to bind mount over
		if [[ ! -f $resolv_conf ]]; then
			install -Dm644 /dev/null "$resolv_conf" || return 1
		fi
	elif [[ ! -e $chrootdir/etc/resolv.conf ]]; then
		# The chroot might not have a resolv.conf.
		[ -e /etc/resolv.conf ] && cp /etc/resolv.conf $chrootdir/etc/resolv.conf
		return 0
	fi

	chroot_add_mount /etc/resolv.conf "$resolv_conf" --bind
}

check_create_user()
{
	local COMMANDS=
	REAL_USER=`env | grep SUDO_USER | awk -F "=" '{ print $2 }'`
	if ! grep -q $REAL_USER $1/etc/passwd ; then
		REAL_UID=`env | grep SUDO_UID | awk -F "=" '{ print $2 }'`
		COMMANDS="adduser -u $REAL_UID $REAL_USER;"
	fi
	COMMANDS="${COMMANDS} su $REAL_USER"
	insert_command $COMMANDS

	[ -d $1/home/$REAL_USER ] || mkdir -p $1/home/$REAL_USER
	chroot_add_mount /home/$REAL_USER "$1/home/$REAL_USER" -o rbind
}

bind_mounts()
{
	for dir in ${BIND_MOUNTS[@]}
	do
		[ -d $1/$dir ] || mkdir -p $1/$dir
		chroot_add_mount $dir "$1/$dir" -o rbind
	done
}

package_check()
{
	command -v $1 >/dev/null 2>&1 || { echo >&2 "${1} not installed. Aborting."; exit 1; }
}

(( EUID == 0 )) || die 'This script must be run with root privileges'

parse_args $@

package_check qemu-arm-static

[[ -d $chrootdir ]] || die "Can't create chroot on non-directory %s" "$chrootdir"

chroot_setup "$chrootdir" || die "failed to setup chroot %s" "$chrootdir"
chroot_add_resolv_conf "$chrootdir" || die "failed to setup resolv.conf"
qemu_arm_setup "$chrootdir" || die "failed to setup qemu_arm"
if [ "$USER" != "" ]; then
	check_create_user "$chrootdir" "$USER" || die "failed to setup user environment"
fi
bind_mounts "$chrootdir"

if [ "$PRE_CHROOT_CMD" != "" ]; then
	/bin/bash $PRE_CHROOT_CMD
fi

if [ "$EXECUTE_COMMANDS" == "" ]; then
	chroot "$chrootdir" /bin/bash
else
	chroot "$chrootdir" /bin/bash -c "${EXECUTE_COMMANDS}"
fi

if [ "$POST_CHROOT_CMD" != "" ]; then
	/bin/bash $POST_CHROOT_CMD
fi
