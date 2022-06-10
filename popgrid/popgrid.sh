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

GS1_CACHE=GS1_XML_3-4-1_Publication.zip
if [ -f ${SCRIPTS_DIR}/cache/$GS1_CACHE ]; then
  echo -e "$PREFIX GS1 xml cached. Skipping download."
else
  echo -e "$PREFIX GS1 xml not cached. Downloading..."
  curl https://www.gs1.org/docs/EDI/xml/3.4.1/GS1_XML_3-4-1_Publication.zip -o ${SCRIPTS_DIR}/cache/$GS1_CACHE
fi

echo -e "$PREFIX $ALPHA_LABEL Copying GS1 xml to ${COLOR_WHITE}gridd-alpha$COLOR_NONE"
docker exec gridd-alpha mkdir /var/cache/grid/xsd_artifact_cache
docker cp $SCRIPTS_DIR/cache/$GS1_CACHE gridd-alpha:/var/cache/grid/xsd_artifact_cache/$GS1_CACHE
docker-compose exec gridd-alpha grid download-xsd

if [ "$(docker-compose exec -T splinterd-alpha splinter circuit propose --help | grep -c auth-type)" -ge 1 ]; then
   AUTH_TYPE=" --auth-type trust"
else
   AUTH_TYPE=
fi

function exit_on_fail() {
  echo -e "$PREFIX Running $@"
  if RESULT=$($@ 2>&1); then
    :
  else
    echo -e "$RESULT"
    echo -e "$PREFIX Bailing due to error"
    exit
  fi
}

echo -e "$PREFIX $ALPHA_LABEL Creating circuit proposal"
exit_on_fail docker-compose exec -T splinterd-alpha splinter circuit propose \
   --key /registry/alpha.priv \
   --url http://splinterd-alpha:8085  \
   --node alpha-node-000::tcps://splinterd-alpha:8044 \
   --node beta-node-000::tcps://splinterd-beta:8044 \
   --service gsAA::alpha-node-000 \
   --service gsBB::beta-node-000 \
   --service-type "*::scabbard" \
   --management grid \
   $AUTH_TYPE \
   --service-arg "*::admin_keys=$GRIDD_PUBKEY" \
   --service-peer-group gsAA,gsBB

# Looking for the line in this format
# "Circuit: tmuVH-nQ1ab"
CIRCUIT_ID=$(echo "$RESULT" | awk '/Circuit/{print $2; exit}' | tr -d '\r')

echo -e "$PREFIX CIRCUIT_ID=\"$CIRCUIT_ID\""

. $SCRIPTS_DIR/accept.sh $CIRCUIT_ID
