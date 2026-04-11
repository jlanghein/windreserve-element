#!/bin/bash
# Create a room inside an existing space and auto-join all users
# Usage: ./create-room-in-space.sh "SPACE_ID" "Room Name"
#
# Example:
#   ./create-room-in-space.sh "!ZQGdifJYRsfvvOUFtS:matrix.windreserve.de" "Anlagenzugang | Wind Farm Access"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

SPACE_ID="$1"
ROOM_NAME="$2"

if [ -z "$SPACE_ID" ] || [ -z "$ROOM_NAME" ]; then
  echo "Usage: $0 \"SPACE_ID\" \"Room Name\""
  echo ""
  echo "Example:"
  echo "  $0 '!ZQGdifJYRsfvvOUFtS:matrix.windreserve.de' 'Anlagenzugang | Wind Farm Access'"
  exit 1
fi

# Get admin token
echo "Getting admin token..."
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# Get all active users (excluding synapse-admin, bots, and deactivated)
USERS=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v2/users?limit=50&deactivated=false' -H 'Authorization: Bearer $TOKEN'" | jq -r '.users[].name' | grep -v "^@synapse-admin" | grep -v "^@agentwind" | grep -v "^@agentstatus" | grep -v "^@botwindautomat" | grep -v "^@robot-n8n")

# Create room with JSON properly escaped
echo "Creating room: $ROOM_NAME"
ROOM_JSON=$(jq -n --arg name "$ROOM_NAME" '{"name": $name, "preset": "private_chat"}')
ROOM_ID=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/createRoom' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '${ROOM_JSON}'" | jq -r '.room_id')

if [ -z "$ROOM_ID" ] || [ "$ROOM_ID" = "null" ]; then
  echo "ERROR: Failed to create room"
  exit 1
fi

echo "Room ID: $ROOM_ID"

# URL-encode the space ID and room ID for the API path
ENCODED_SPACE_ID=$(echo -n "$SPACE_ID" | jq -sRr @uri)
ENCODED_ROOM_ID=$(echo -n "$ROOM_ID" | jq -sRr @uri)

# Add room to space
echo "Adding room to space..."
ssh root@$SERVER_IP "docker exec synapse curl -s -X PUT 'http://localhost:8008/_matrix/client/r0/rooms/$ENCODED_SPACE_ID/state/m.space.child/$ENCODED_ROOM_ID' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"via\": [\"matrix.windreserve.de\"]}'" > /dev/null

# Join users to room using while loop with -n flag to prevent ssh from consuming stdin
echo -n "Joining users to room"
ENCODED_ROOM=$(echo -n "$ROOM_ID" | jq -sRr @uri)
while IFS= read -r user; do
  [ -z "$user" ] && continue
  USER_JSON=$(jq -n --arg u "$user" '{"user_id": $u}')
  ssh -n root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_synapse/admin/v1/join/$ENCODED_ROOM' \
    -H 'Authorization: Bearer $TOKEN' \
    -H 'Content-Type: application/json' \
    -d '${USER_JSON}'" > /dev/null 2>&1
  echo -n "."
done <<< "$USERS"
echo " done"

echo ""
echo "=== Summary ==="
echo "Room: $ROOM_NAME"
echo "Room ID: $ROOM_ID"
echo "Added to Space: $SPACE_ID"
