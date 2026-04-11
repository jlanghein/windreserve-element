#!/bin/bash
# Set room topic (description) for a Matrix room
# Usage: ./set-room-topic.sh "ROOM_ID" "TOPIC"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env" 2>/dev/null || true
source "$SCRIPT_DIR/../element-secrets.env" 2>/dev/null || true

SERVER_IP="${SERVER_IP:-91.99.184.79}"
SYNAPSE_ADMIN_USER="${SYNAPSE_ADMIN_USER:-synapse-admin}"
SYNAPSE_ADMIN_PASS="${SYNAPSE_ADMIN_PASS:-Untwist-Jujitsu-Anguished-Slackness3}"

ROOM_ID="$1"
TOPIC="$2"

if [ -z "$ROOM_ID" ] || [ -z "$TOPIC" ]; then
  echo "Usage: $0 \"ROOM_ID\" \"TOPIC\""
  echo ""
  echo "Example:"
  echo "  $0 '!abc123:matrix.windreserve.de' 'Wind farm location: https://maps.google.com/...'"
  exit 1
fi

# Get admin token
echo "Getting admin token..."
TOKEN=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X POST 'http://localhost:8008/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"$SYNAPSE_ADMIN_USER\",\"password\":\"$SYNAPSE_ADMIN_PASS\"}'" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

echo "Setting topic for room: $ROOM_ID"

# URL-encode the room ID for the API path
ENCODED_ROOM_ID=$(echo -n "$ROOM_ID" | jq -sRr @uri)

# Properly escape the topic for JSON
JSON_PAYLOAD=$(jq -n --arg topic "$TOPIC" '{"topic": $topic}')

# Set room topic using state event
RESULT=$(ssh root@$SERVER_IP "docker exec synapse curl -s -X PUT 'http://localhost:8008/_matrix/client/r0/rooms/$ENCODED_ROOM_ID/state/m.room.topic' \
  -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '$JSON_PAYLOAD'")

echo "Result: $RESULT"

if echo "$RESULT" | jq -e '.event_id' > /dev/null 2>&1; then
  echo "SUCCESS: Topic set!"
else
  echo "ERROR: Failed to set topic"
  echo "$RESULT"
  exit 1
fi
