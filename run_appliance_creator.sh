#!/bin/bash

KS_FILE=$1
OUTPUT_DIR=$2
NAME=$3
VERSION=$4

appliance-creator -c $KS_FILE -d -v --logfile $OUTPUT_DIR/appliance.log \
	-o $OUTPUT_DIR --format raw \
	--cache /root/cache \
	--vmem 2048 \
	--no-archive \
	--no-firewall-config \
	--arm-chroot \
	--name $NAME --version $VERSION \
	--release $NAME
