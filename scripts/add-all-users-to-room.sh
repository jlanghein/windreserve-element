#!/bin/bash
# Add all active users to a room or space
# Usage: ./add-all-users-to-room.sh "ROOM_ID"
#
# Example:
#   ./add-all-users-to-room.sh "!KlpKhRrUDuAEuoqBXK:matrix.windreserve.de"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

ROOM_ID="$1"

if [ -z "$ROOM_ID" ]; then
  echo "Usage: $0 \"ROOM_ID\""
  echo ""
  echo "Example:"
  echo "  $0 '!KlpKhRrUDuAEuoqBXK:matrix.windreserve.de'"
  exit 1
fi

# Get admin token
echo "Getting admin token..."
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# Make admin room admin and join
echo "Making admin room admin..."
ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_synapse/admin/v1/rooms/$ROOM_ID/make_room_admin' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{\"user_id\": \"@synapse-admin:matrix.windreserve.de\"}'" > /dev/null

echo "Joining admin to room..."
ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/join/$ROOM_ID' -H 'Authorization: Bearer $TOKEN'" > /dev/null

# Get all active users (excluding synapse-admin and bots)
USERS=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v2/users?limit=50' -H 'Authorization: Bearer $TOKEN'" | jq -r '.users[].name' | grep -v "^@synapse-admin" | grep -v "^@agentwind" | grep -v "^@agentstatus" | grep -v "^@botwindautomat" | grep -v "^@robot-n8n" | tr '\n' ' ')

echo -n "Adding users to room"
for user in $USERS; do
  ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_synapse/admin/v1/join/$ROOM_ID' \
    -H 'Authorization: Bearer $TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{\"user_id\": \"$user\"}'" > /dev/null 2>&1
  echo -n "."
done
echo " done"

# Show result
echo ""
echo "=== Result ==="
ssh root@$SERVER_IP "docker exec synapse curl -s 'http://localhost:8008/_synapse/admin/v1/rooms/$ROOM_ID' -H 'Authorization: Bearer $TOKEN'" | jq '{name, joined_members}'
