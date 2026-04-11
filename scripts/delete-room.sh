#!/bin/bash
# Delete a Matrix room
# Usage: ./delete-room.sh "!roomId:matrix.windreserve.de"
#
# Options:
#   -f, --force    Skip confirmation prompt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

FORCE=false
ROOM_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    *)
      ROOM_ID="$1"
      shift
      ;;
  esac
done

if [ -z "$ROOM_ID" ]; then
  echo "Usage: $0 [-f|--force] \"!roomId:matrix.windreserve.de\""
  echo ""
  echo "Options:"
  echo "  -f, --force    Skip confirmation prompt"
  echo ""
  echo "Example:"
  echo "  $0 \"!abc123:matrix.windreserve.de\""
  echo "  $0 -f \"!abc123:matrix.windreserve.de\""
  exit 1
fi

# Get admin token
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

# Get room info
echo "Room info:"
ROOM_INFO=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v1/rooms/$ROOM_ID' -H 'Authorization: Bearer $TOKEN'")

if echo "$ROOM_INFO" | jq -e '.errcode' > /dev/null 2>&1; then
  echo "ERROR: Room not found"
  exit 1
fi

echo "$ROOM_INFO" | jq '{name, joined_members}'

# Confirm deletion
if [ "$FORCE" != true ]; then
  read -p "Are you sure you want to delete this room? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
  fi
fi

# Delete room
echo "Deleting room..."
RESULT=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X DELETE 'http://localhost:8008/_synapse/admin/v2/rooms/$ROOM_ID' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"purge\": true}'")

if echo "$RESULT" | jq -e '.delete_id' > /dev/null 2>&1; then
  DELETE_ID=$(echo "$RESULT" | jq -r '.delete_id')
  echo "Delete initiated: $DELETE_ID"
  
  # Wait for completion
  echo -n "Waiting for completion"
  for i in {1..30}; do
    sleep 2
    STATUS=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X GET 'http://localhost:8008/_synapse/admin/v2/rooms/$ROOM_ID/delete_status' -H 'Authorization: Bearer $TOKEN'" | jq -r '.results[0].status // "pending"')
    echo -n "."
    if [ "$STATUS" = "complete" ]; then
      echo " done!"
      echo "Room deleted successfully"
      exit 0
    fi
  done
  echo ""
  echo "Delete still in progress. Check status with:"
  echo "  curl /_synapse/admin/v2/rooms/$ROOM_ID/delete_status"
else
  echo "ERROR: $RESULT"
  exit 1
fi
