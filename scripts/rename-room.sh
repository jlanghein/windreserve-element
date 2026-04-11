#!/bin/bash
# Rename a Matrix room
# Usage: ./rename-room.sh "!roomId:matrix.windreserve.de" "New Room Name"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

ROOM_ID="$1"
NEW_NAME="$2"

if [ -z "$ROOM_ID" ] || [ -z "$NEW_NAME" ]; then
  echo "Usage: $0 \"!roomId:matrix.windreserve.de\" \"New Room Name\""
  echo ""
  echo "Example:"
  echo "  $0 \"!abc123:matrix.windreserve.de\" \"01 - 12345\""
  exit 1
fi

# Get admin token
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# Get current name
echo "Current name:"
ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v1/rooms/$ROOM_ID' -H 'Authorization: Bearer $TOKEN'" | jq -r '.name'

# Rename room
echo "Renaming to: $NEW_NAME"
RESULT=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X PUT 'http://localhost:8008/_matrix/client/r0/rooms/$ROOM_ID/state/m.room.name' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"name\": \"$NEW_NAME\"}'")

if echo "$RESULT" | jq -e '.event_id' > /dev/null 2>&1; then
  echo "Success!"
else
  echo "ERROR: $RESULT"
  exit 1
fi
