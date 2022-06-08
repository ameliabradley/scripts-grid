#!/bin/bash
set -e

APP_NAME=POPGRID
COLOR_RED="\033[0;31m"
COLOR_WHITE="\033[1;37m"
COLOR_GREEN="\033[0;32m"
COLOR_CYAN="\033[0;36m"
COLOR_NONE="\033[0m"
PREFIX="$COLOR_RED[$COLOR_CYAN$APP_NAME$COLOR_RED]$COLOR_NONE"

SOURCE_DIR=$(git rev-parse --show-toplevel)
if [[ -z "$VALID_GRID" ]]; then
  if [ "$(git remote -v | grep -c hyperledger/grid)" -ge 0 ]; then
    VALID_GRID=1
    echo -e "$PREFIX Found base directory $COLOR_WHITE$SOURCE_DIR$COLOR_NONE"
  else
    VALID_GRID=0
    echo -e "$PREFIX [ERROR] Base directory $COLOR_WHITE$SOURCE_DIR$COLOR_NONE is not ${COLOR_WHITE}hyperledger/grid$COLOR_NONE"
    exit
  fi
fi

COMPOSE_DIR="examples/splinter"
