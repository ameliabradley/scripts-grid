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
BUILD_DIR=/xgridbuild
CARGO_TARGET_DIR=${BUILD_DIR}/target
REPO_VERSION=$(cat $SOURCE_DIR/VERSION)-dev

CARGO_ARGS=" ${@:-"--features=experimental"}"

echo -e "$PREFIX Building version $COLOR_WHITE$REPO_VERSION$COLOR_NONE"

echo -e "$PREFIX Building with $COLOR_WHITE$CARGO_ARGS$COLOR_NONE"

echo -e "$PREFIX Building ${COLOR_WHITE}gridd-builder.dockerfile$COLOR_NONE";

docker build -f $SCRIPTS_DIR/gridd-builder.dockerfile $SCRIPTS_DIR -t gridd-builder

GRID_BASE=xgridd-base

function build_base {
  echo -e "$PREFIX Creating $COLOR_WHITE$GRID_BASE$COLOR_NONE"
  docker build -f $SCRIPTS_DIR/gridd-base.dockerfile $SCRIPTS_DIR -t $GRID_BASE
}

openssl sha1 $SCRIPTS_DIR/gridd-base.dockerfile > $SCRIPTS_DIR/cache/grid-base-sha1
if [ $( docker images | grep $GRID_BASE | wc -l ) -gt 0 ]; then
  echo -e "$PREFIX $COLOR_WHITE$GRID_BASE$COLOR_NONE already exists"

  # Here we're using a hash in the root of the docker image
  # on the off chance we change the base docker file. Ideally
  # though, this base image continually updates with all the
  # necessary grid dependency libraries and never ever gets rebuilt.
  docker run $GRID_BASE cat /HASH > $SCRIPTS_DIR/cache/grid-base-image-sha1
  if cmp --silent -- $SCRIPTS_DIR/cache/grid-base-sha1 $SCRIPTS_DIR/cache/grid-base-image-sha1; then
    echo -e "$PREFIX $COLOR_WHITE$GRID_BASE$COLOR_NONE hash matches"
  else
    echo -e "$PREFIX $COLOR_WHITE$GRID_BASE$COLOR_NONE hash does not match"
    build_base
  fi
else
  echo -e "$PREFIX $COLOR_WHITE$GRID_BASE$COLOR_NONE does not exist"
  build_base
fi

INSTANCE_NAME=xgridd-builder-instance
if [ $( docker ps | grep $INSTANCE_NAME | wc -l ) -gt 0 ]; then
  echo -e "$PREFIX $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE already exists"
else
  echo -e "$PREFIX $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE does not exist. creating..."
  docker run -t -d --name=$INSTANCE_NAME gridd-builder
fi

echo 
echo -e "$PREFIX Copying source from $COLOR_WHITE$SOURCE_DIR$COLOR_NONE to $COLOR_WHITE$INSTANCE_NAME$COLOR_NONE"

for file in $SOURCE_DIR/*
do
  BASENAME=$(basename $file)
  if [ "$BASENAME" = "target" ]; then
    continue;
  fi

  if [ -d $file ]; then
    file=$file/.
  fi

  DEST=$BUILD_DIR/$BASENAME
  echo -e "$PREFIX Copying $COLOR_WHITE$BASENAME$COLOR_NONE to $DEST"
  docker cp $file $INSTANCE_NAME:$DEST
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
	-e "BUILD_DIR=${BUILD_DIR}" \
	-e "CARGO_TARGET_DIR=${CARGO_TARGET_DIR}" \
	-e "PREFIX=$PREFIX_INTERNAL" \
	-e "CARGO_ARGS=${CARGO_ARGS}" \
	-e "REPO_VERSION=${REPO_VERSION}" \
	$INSTANCE_NAME /usr/bin/readysteadygo

echo
echo -e "$PREFIX Creating new ${COLOR_WHITE}gridd$COLOR_NONE image";

docker cp $INSTANCE_NAME:$CARGO_TARGET_DIR/debian/grid-cli_${REPO_VERSION}_arm64.deb $SCRIPTS_DIR/cache/
docker cp $INSTANCE_NAME:$CARGO_TARGET_DIR/debian/grid-daemon_${REPO_VERSION}_arm64.deb $SCRIPTS_DIR/cache/
docker build -f $SCRIPTS_DIR/gridd.dockerfile $SCRIPTS_DIR -t gridd
docker tag gridd $GRID_BASE

echo -e "$PREFIX Successfully pushed new ${COLOR_WHITE}gridd$COLOR_NONE image 🎉";

echo -e "$PREFIX (Reminder) Built with $COLOR_WHITE$CARGO_ARGS$COLOR_NONE"
