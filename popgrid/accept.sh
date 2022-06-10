#!/bin/bash

SCRIPTS_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source $SCRIPTS_DIR/shared.sh

cd $SOURCE_DIR
cd $COMPOSE_DIR

# For newer versions of splinter
#ALPHA_ARGS=" --key /registry/alpha.priv --url http://127.0.0.1:8085"
#BETA_ARGS=" --key /registry/beta.priv --url http://127.0.0.1:8085"

ALPHA_ARGS=""
BETA_ARGS=""

ORG_ID=myorg
ORG_FULLNAME=MyOrganization
ORG_ALTID=gs1_company_prefix:013600

CIRCUIT_ID=$1

function check_proposal() {
  exit_on_fail docker-compose exec splinterd-beta splinter circuit proposals $BETA_ARGS
  echo "$RESULT" | grep -q "$CIRCUIT_ID"
}
until check_proposal
do
  echo -e "$PREFIX $BETA_LABEL Waiting for proposal acknowledgment of $COLOR_WHITE$CIRCUIT_ID$COLOR_NONE..."
  sleep 0.1
done

docker-compose exec splinterd-beta splinter circuit vote \
    --key /registry/beta.priv \
    --url http://splinterd-beta:8085 \
    $CIRCUIT_ID \
    --accept

echo -e "$PREFIX Successfully setup circuit $CIRCUIT_ID" 

# The following waits for all the contracts to be setup.
# 
# Example output
#
# NAME                VERSIONS OWNERS                                                             
# grid_location       2        03e3d5fcab7f7040a7449dfc578a126cd5a8acc638826eafc64e053f2d64294421 
# grid_pike           2        03e3d5fcab7f7040a7449dfc578a126cd5a8acc638826eafc64e053f2d64294421 
# grid_purchase_order 2        03e3d5fcab7f7040a7449dfc578a126cd5a8acc638826eafc64e053f2d64294421 
# grid_product        2        03e3d5fcab7f7040a7449dfc578a126cd5a8acc638826eafc64e053f2d64294421 
# grid_schema         2        03e3d5fcab7f7040a7449dfc578a126cd5a8acc638826eafc64e053f2d64294421
docker-compose exec splinterd-beta cat /registry/alpha.priv > ~/key
docker cp ~/key scabbard-cli-alpha:/key
function check_contracts() {
  # TODO: Add --key after splinter is upgraded and the docker-compose
  # gets updated to contain a key
  exit_on_fail docker-compose exec scabbard-cli-alpha scabbard contract list -U http://splinterd-alpha:8085 --service-id $CIRCUIT_ID::gsAA
  RESULT=$(echo "$RESULT" | wc -l)
}
until check_contracts; [ $RESULT -gt "5" ]
do
  echo -e "$PREFIX Waiting for contracts to be setup..."
  sleep 1
done

#### GRID STEPS

echo -e "$PREFIX $ALPHA_LABEL Generating alpha-agent keys"
docker-compose exec gridd-alpha grid keygen alpha-agent

echo -e "$PREFIX $ALPHA_LABEL Creating organization $ORG_ID"
docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid organization create \
  $ORG_ID $ORG_FULLNAME \
  --alternate-ids $ORG_ALTID

function check_org() {
  exit_on_fail docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid organization list
  echo "$RESULT" | grep -q $ORG_ID
}
until check_org; echo "$RESULT"
do
  echo -e "$PREFIX $BETA_LABEL Waiting for beta to acknowledge organization..."
  sleep 0.5
done

echo -e "$PREFIX Organization $ORG_ID successfully created"

echo -e "$PREFIX $ALPHA_LABEL Creating role po-partner"
docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid role create \
 $ORG_ID po-partner \
 --description "purchase order partner permissions" \
 --active \
 --allowed-orgs myorg \
 --permissions "po::partner"
 #--permissions "po::buyer,po::seller,po::partner,po::draft"

function check_partner_role_added() {
  exit_on_fail docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid role list $ORG_ID
  echo "$RESULT" | grep -q po-partner
}
until check_partner_role_added; echo "$RESULT"
do
  echo -e "$PREFIX $BETA_LABEL Waiting for role to be added..."
  sleep 0.5
done

echo -e "$PREFIX $ALPHA_LABEL Giving agent po-partner role"
AGENT_PUBKEY=$(docker exec gridd-alpha cat /root/.grid/keys/alpha-agent.pub | tr -d '\r')
docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid agent update \
myorg $AGENT_PUBKEY \
--active \
--role admin \
--role po-partner 

function check_partner_role_given() {
  exit_on_fail docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid agent list
  echo "$RESULT" | grep -q po-partner
}
until check_partner_role_given; echo $RESULT
do
  echo -e "$PREFIX $BETA_LABEL Waiting for agent to be given role..."
  sleep 0.5
done

function test_po {
  echo -e "$PREFIX $ALPHA_LABEL Creating purchase order"
  PO_ID=$1
  docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid po create --buyer-org myorg --seller-org myorg --workflow-id "built-in::collaborative::v1" --workflow-state issued --url http://localhost:8080 --key /root/.grid/keys/alpha-agent.priv --service-id=$CIRCUIT_ID::gsAA --uid=$PO_ID

  until $(docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid po list | grep -q $PO_ID)
  do
    echo -e "$PREFIX $BETA_LABEL Waiting for po to be created..."
    sleep 0.5
  done

  echo -e "$PREFIX $ALPHA_LABEL Creating purchase order version"
  PO_VERSION_ID=01
  docker cp $SCRIPTS_DIR/purchase-order-valid.xml gridd-alpha:/test-po.xml
  docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid po version create $PO_ID $PO_VERSION_ID --workflow-state proposed --not-draft --order-xml /test-po.xml

  until $(docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid po version list $PO_ID | grep -q $PO_VERSION_ID)
  do
    echo -e "$PREFIX $BETA_LABEL Waiting for po version to be created..."
    sleep 0.5
  done

  # This fails for some reason
  echo -e "$PREFIX $ALPHA_LABEL Updating purchase order version"
  docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid po version update $PO_ID $PO_VERSION_ID --workflow-state proposed --not-draft --order-xml /test-po.xml

  #until $(docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid po version list $PO_ID | grep $PO_VERSION_ID | awk '{print $5}' | grep -q 2)
  #do
  #  echo "Waiting for po version to be updated..."
  #  sleep 0.5
  #done
}

test_po PO-KyilV-Aaaa

#
# EXTENDED TESTS
#

echo -e "$PREFIX $ALPHA_LABEL Creating role po-buyer"
docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid role create \
 $ORG_ID po-buyer \
 --description "purchase order buyer permissions" \
 --active \
 --allowed-orgs myorg \
 --permissions "po::buyer"

function check_buyer_role_added() {
  exit_on_fail docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid role list $ORG_ID
  echo "$RESULT" | grep -q po-buyer
}
until check_buyer_role_added; echo $RESULT
do
  echo -e "$PREFIX $BETA_LABEL Waiting for role to be added..."
  sleep 0.5
done

echo -e "$PREFIX $ALPHA_LABEL Giving agent po-buyer role"
AGENT_PUBKEY=$(docker exec gridd-alpha cat /root/.grid/keys/alpha-agent.pub | tr -d '\r')
docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsAA -e GRID_DAEMON_KEY=alpha-agent gridd-alpha grid agent update \
myorg $AGENT_PUBKEY \
--active \
--role admin \
--role po-buyer 

function check_buyer_role_given() {
  exit_on_fail docker-compose exec -e GRID_SERVICE_ID=$CIRCUIT_ID::gsBB gridd-beta grid agent list
  echo "$RESULT" | grep -q po-buyer
}
until check_buyer_role_given; echo $RESULT
do
  echo -e "$PREFIX $BETA_LABEL Waiting for agent to be given role..."
  sleep 0.5
done

# TODO: Update script to test po-buyer steps for creating a po
#test_po PO-KyilV-Bbbb

echo -e "$PREFIX Successfully setup and tested splinter gridd 🎉"
