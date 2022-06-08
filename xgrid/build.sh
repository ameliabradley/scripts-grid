#!/bin/bash

set -e

APP_NAME=❌GRID
COLOR_RED="\033[0;31m"
COLOR_WHITE="\033[1;37m"
COLOR_CYAN="\033[0;36m"
COLOR_NONE="\033[0m"
PREFIX="$COLOR_RED[$COLOR_CYAN$APP_NAME$COLOR_RED]$COLOR_NONE"
PREFIX_INTERNAL="$COLOR_RED[docker] [$COLOR_CYAN$APP_NAME$COLOR_RED]$COLOR_NONE"

SOURCE_DIR=$(git rev-parse --show-toplevel)
if [ "$(git remote -v | grep -c hyperledger/grid)" -ge 0 ]; then
  echo -e "$PREFIX Found base directory $COLOR_WHITE$SOURCE_DIR$COLOR_NONE"
else
  echo -e "$PREFIX [ERROR] Base directory $COLOR_WHITE$SOURCE_DIR$COLOR_NONE is not ${COLOR_WHITE}hyperledger/grid$COLOR_NONE"
  exit
fi

SCRIPTS_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CACHE_DIR=${SCRIPTS_DIR}/cache
CARGO_HOME=${CACHE_DIR}/cargo
CARGO_TARGET_DIR=${CACHE_DIR}/target
REPO_VERSION=$(${SOURCE_DIR}/bin/get_version)

CARGO_ARGS=" ${@:-"--features=experimental"}"

echo -e "$PREFIX Building version $COLOR_WHITE$REPO_VERSION$COLOR_NONE"

echo -e "$PREFIX Building with $COLOR_WHITE$CARGO_ARGS$COLOR_NONE"

echo -e "$PREFIX Building ${COLOR_WHITE}grid-builder.dockerfile$COLOR_NONE";

docker build -f $SCRIPTS_DIR/gridd-builder.dockerfile $SCRIPTS_DIR -t gridd-builder

docker build -f $SCRIPTS_DIR/gridd-base.dockerfile $SCRIPTS_DIR -t gridd-base

INSTANCE_NAME=gridd-builder-instance
if [ $( docker ps | grep $INSTANCE_NAME | wc -l ) -gt 0 ]; then
  echo -e "$PREFIX $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE already exists"
else
  echo -e "$PREFIX $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE does not exist. creating..."
  docker run -t -d --name=$INSTANCE_NAME gridd-builder
fi

echo 
echo -e "$PREFIX Copying source from $COLOR_WHITE$SOURCE_DIR$COLOR_NONE to $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE"

docker exec $INSTANCE_NAME mkdir -p /mnt/grid
for file in $SOURCE_DIR/*
do
  BASENAME=$(basename $file)
  if [ "$BASENAME" = "target" ]; then
    continue;
  fi

  echo -e "$PREFIX Copying $COLOR_WHITE$BASENAME$COLOR_NONE"
  docker cp $file $INSTANCE_NAME:/mnt/grid/$BASENAME
done

echo
echo -e "$PREFIX Copying ${COLOR_WHITE}script.sh$COLOR_NONE to $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE"
docker cp $SCRIPTS_DIR/script.sh $INSTANCE_NAME:/usr/bin/readysteadygo

echo
echo -e "$PREFIX Cross-compiling on $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE";

docker start $INSTANCE_NAME

docker exec \
	-ti \
	-e "TERM=xterm-256color" \
	-e "CARGO_HOME=/mnt/cache/cargo" \
	-e "CARGO_TARGET_DIR=/mnt/cache/target" \
	-e "PREFIX=$PREFIX_INTERNAL" \
	-e "CARGO_ARGS=${CARGO_ARGS}" \
	-e "REPO_VERSION=${REPO_VERSION}" \
	$INSTANCE_NAME /usr/bin/readysteadygo

echo
echo -e "$PREFIX Creating new ${COLOR_WHITE}gridd$COLOR_NONE image";

docker cp $INSTANCE_NAME:/mnt/cache/target/debian/grid-cli_${REPO_VERSION}_arm64.deb $SCRIPTS_DIR/cache/
docker cp $INSTANCE_NAME:/mnt/cache/target/debian/grid-daemon_${REPO_VERSION}_arm64.deb $SCRIPTS_DIR/cache/
docker build -f $SCRIPTS_DIR/gridd.dockerfile $SCRIPTS_DIR -t gridd

echo -e "$PREFIX Successfully pushed new ${COLOR_WHITE}gridd$COLOR_NONE image 🎉";

echo -e "$PREFIX (Reminder) Built with $COLOR_WHITE$CARGO_ARGS$COLOR_NONE"
