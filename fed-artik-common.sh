#!/bin/bash

out() { printf "$1 $2\n" "${@:3}"; }
error() { out "==> ERROR:" "$@"; } >&2
msg() { out "==>" "$@"; }
msg2() { out "  ->" "$@";}
die() { error "$@"; exit 1; }

SCRIPT_DIR=`dirname "$(readlink -f "$0")"`
if [ $SUDO_USER ]; then user=$SUDO_USER; else user=`whoami`; fi

append_command()
{
	EXECUTE_COMMANDS+="${1};"
}

insert_command()
{
	EXECUTE_COMMANDS="${@}; ${EXECUTE_COMMANDS}"
}
