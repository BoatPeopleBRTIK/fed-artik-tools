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

parse_config()
{
	configfile=$1
	shopt -s extglob
	while IFS='= ' read lhs rhs
	do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%\#*}"    # Del in line right comments
			rhs="${rhs%%*( )}"   # Del trailing spaces
			rhs="${rhs%\"*}"     # Del opening string quotes
			rhs="${rhs#\"*}"     # Del closing string quotes
			export $lhs=$rhs
		fi
	done < $configfile
}
