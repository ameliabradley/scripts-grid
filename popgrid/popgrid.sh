#!/bin/bash
set -e

SCRIPTS_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source $SCRIPTS_DIR/shared.sh

cd $SOURCE_DIR
cd $COMPOSE_DIR

# Remove all existing images and volumes
echo
echo -e "$PREFIX Stopping $COLOR_WHITE$COMPOSE_DIR$COLOR_NONE"
docker-compose down -v

# Pull newer versions of updated images (per Grid docs)
echo
echo -e "$PREFIX Pulling commonly updated images"
docker-compose pull generate-registry db-alpha scabbard-cli-alpha splinterd-alpha

# Start environment in the background
echo
echo -e "$PREFIX Starting $COLOR_WHITE$COMPOSE_DIR$COLOR_NONE"
docker-compose up -d

# Just because the last command returns doesn't mean Grid is ready.
# Here we'll ping Grid until we are satisified that it is up.
# There is currently no status endpoint, but this will suffice.
# We're expecting a response like this:
#
#{"status_code":400,"message":"Service ID is not present, but grid is running in splinter mode"}
until $(curl -s http://localhost:8080/batch_statuses | grep -q grid)
do
  echo -e "$PREFIX $ALPHA_LABEL Waiting for rest API to return..."
  sleep 1
done

echo -e "$PREFIX $ALPHA_LABEL Rest API ready"

# Do the same for Grid beta
until $(curl -s http://localhost:8081/batch_statuses | grep -q grid)
do
  echo -e "$PREFIX $BETA_LABEL Waiting for rest API to return..."
  sleep 1
done

echo -e "$PREFIX $BETA_LABEL Rest API ready"

GRIDD_PUBKEY=$(docker exec gridd-alpha cat /etc/grid/keys/gridd.pub | tr -d '\r')
echo -e "$PREFIX GRIDD_PUBKEY=\"$GRIDD_PUBKEY\""

# This isn't used by the script, but it could be useful if you're manually
# executing commands
echo -e "$PREFIX $ALPHA_LABEL Publishing gridd pubkey to alpha"
docker-compose exec splinterd-alpha echo $GRIDD_PUBKEY > $SCRIPTS_DIR/cache/gridd.pub 

echo -e "$PREFIX $ALPHA_LABEL Creating circuit proposal"
CIRCUIT_ID=$(docker-compose exec splinterd-alpha splinter circuit propose \
   --key /registry/alpha.priv \
   --url http://splinterd-alpha:8085  \
   --node alpha-node-000::tcps://splinterd-alpha:8044 \
   --node beta-node-000::tcps://splinterd-beta:8044 \
   --service gsAA::alpha-node-000 \
   --service gsBB::beta-node-000 \
   --service-type *::scabbard \
   --management grid \
   --service-arg *::admin_keys=$GRIDD_PUBKEY \
   --service-peer-group gsAA,gsBB | awk '/Circuit/{print $2}' | tr -d '\r')

echo -e "$PREFIX CIRCUIT_ID=\"$CIRCUIT_ID\""

. $SCRIPTS_DIR/accept.sh $CIRCUIT_ID
