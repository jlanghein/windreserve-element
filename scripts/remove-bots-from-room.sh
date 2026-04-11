#!/bin/bash
# Remove bot accounts from a room
# Usage: ./remove-bots-from-room.sh "ROOM_ID"
#
# Removes these bot accounts:
#   - @agentwind:matrix.windreserve.de
#   - @agentstatus:matrix.windreserve.de
#   - @botwindautomat:matrix.windreserve.de
#   - @robot-n8n:matrix.windreserve.de

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
  echo "  $0 '!TxAMpkGiKUmLwBkGMK:matrix.windreserve.de'"
  exit 1
fi

# Bot accounts to remove
BOTS=(
  "@agentwind:matrix.windreserve.de"
  "@agentstatus:matrix.windreserve.de"
  "@botwindautomat:matrix.windreserve.de"
  "@robot-n8n:matrix.windreserve.de"
)

# Get admin token
echo "Getting admin token..."
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# URL-encode room ID
ENCODED_ROOM=$(echo -n "$ROOM_ID" | jq -sRr @uri)

echo "Removing bots from room..."
for bot in "${BOTS[@]}"; do
  ENCODED_USER=$(echo -n "$bot" | jq -sRr @uri)
  result=$(ssh -n root@$SERVER_IP "docker exec synapse curl -s -X DELETE 'http://localhost:8008/_synapse/admin/v1/rooms/$ENCODED_ROOM/members/$ENCODED_USER' -H 'Authorization: Bearer $TOKEN'" 2>&1)
  # Alternative: kick via state event
  ssh -n root@$SERVER_IP "docker exec synapse curl -s -X PUT 'http://localhost:8008/_matrix/client/r0/rooms/$ENCODED_ROOM/state/m.room.member/$ENCODED_USER' \
    -H 'Authorization: Bearer $TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{\"membership\": \"leave\"}'" > /dev/null 2>&1
  echo "  Removed: $bot"
done

# Show result
echo ""
echo "=== Result ==="
ssh root@$SERVER_IP "docker exec synapse curl -s 'http://localhost:8008/_synapse/admin/v1/rooms/$ROOM_ID' -H 'Authorization: Bearer $TOKEN'" | jq '{name, joined_members}'
