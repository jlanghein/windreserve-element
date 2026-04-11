#!/bin/bash
# Create a wind farm space with turbine rooms and auto-join all users
# Usage: ./create-wind-farm-space.sh "Wind Farm Name" "01:serial1 02:serial2 03:serial3"
#
# Example:
#   ./create-wind-farm-space.sh "Vahlbruch" "01:51089 02:51076 03:51074"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

WIND_FARM_NAME="$1"
TURBINES="$2"

if [ -z "$WIND_FARM_NAME" ] || [ -z "$TURBINES" ]; then
  echo "Usage: $0 \"Wind Farm Name\" \"01:serial1 02:serial2 ...\""
  echo ""
  echo "Example:"
  echo "  $0 \"Vahlbruch\" \"01:51089 02:51076 03:51074\""
  exit 1
fi

# Get admin token
echo "Getting admin token..."
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# All users to join
USERS=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v2/users?limit=50' -H 'Authorization: Bearer $TOKEN'" | jq -r '.users[].name' | grep -v "^@synapse-admin" | tr '\n' ' ')

echo "Creating space: $WIND_FARM_NAME"
SPACE_ID=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/createRoom' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"name\": \"$WIND_FARM_NAME\", \"preset\": \"private_chat\", \"creation_content\": {\"type\": \"m.space\"}}'" | jq -r '.room_id')

if [ -z "$SPACE_ID" ] || [ "$SPACE_ID" = "null" ]; then
  echo "ERROR: Failed to create space"
  exit 1
fi

echo "Space ID: $SPACE_ID"

# Join users to space
echo -n "Joining users to space"
for user in $USERS; do
  ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_synapse/admin/v1/join/$SPACE_ID' \
    -H 'Authorization: Bearer $TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{\"user_id\": \"$user\"}'" > /dev/null 2>&1
  echo -n "."
done
echo " done"

# Create turbine rooms
for turbine in $TURBINES; do
  anlage="${turbine%%:*}"
  serial="${turbine##*:}"
  room_name="$anlage - $serial"
  
  echo "Creating room: $room_name"
  ROOM_ID=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/createRoom' \
    -H 'Authorization: Bearer $TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{\"name\": \"$room_name\", \"preset\": \"private_chat\"}'" | jq -r '.room_id')
  
  if [ -z "$ROOM_ID" ] || [ "$ROOM_ID" = "null" ]; then
    echo "  ERROR: Rate limited, waiting 60s..."
    sleep 60
    ROOM_ID=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/createRoom' \
      -H 'Authorization: Bearer $TOKEN' \
      -H 'Content-Type: application/json' \
      -d '{\"name\": \"$room_name\", \"preset\": \"private_chat\"}'" | jq -r '.room_id')
  fi
  
  if [ -n "$ROOM_ID" ] && [ "$ROOM_ID" != "null" ]; then
    echo "  Room ID: $ROOM_ID"
    
    # Add to space
    ssh root@$SERVER_IP "docker exec synapse curl -s -X PUT 'http://localhost:8008/_matrix/client/r0/rooms/$SPACE_ID/state/m.space.child/$ROOM_ID' \
      -H 'Authorization: Bearer $TOKEN' \
      -H 'Content-Type: application/json' \
      -d '{\"via\": [\"matrix.windreserve.de\"]}'" > /dev/null
    
    # Join users
    echo -n "  Joining users"
    for user in $USERS; do
      ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_synapse/admin/v1/join/$ROOM_ID' \
        -H 'Authorization: Bearer $TOKEN' \
        -H 'Content-Type: application/json' \
        -d '{\"user_id\": \"$user\"}'" > /dev/null 2>&1
      echo -n "."
    done
    echo " done"
  else
    echo "  ERROR: Failed to create room after retry"
  fi
  
  sleep 2
done

echo ""
echo "=== Summary ==="
echo "Space: $WIND_FARM_NAME = $SPACE_ID"
