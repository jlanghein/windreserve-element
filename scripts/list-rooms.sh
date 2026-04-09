#!/bin/bash
# List all Matrix rooms
# Usage: ./list-rooms.sh

set -e

# Load secrets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env"

# Read admin credentials from element-secrets.env
SYNAPSE_ADMIN_USER=$(grep '^SYNAPSE_ADMIN_USER=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)
SYNAPSE_ADMIN_PASS=$(grep '^SYNAPSE_ADMIN_PASS=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)

echo "=== Fetching room list ==="

ssh root@$SERVER_IP "
cd /root/windreserve-element

# Get admin token
TOKEN=\$(docker compose exec -T synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \\
    -H 'Content-Type: application/json' \\
    -d '{\"type\": \"m.login.password\", \"user\": \"$SYNAPSE_ADMIN_USER\", \"password\": \"$SYNAPSE_ADMIN_PASS\"}' \\
    | jq -r '.access_token')

# List all rooms
docker compose exec -T synapse curl -s \\
    'http://localhost:8008/_synapse/admin/v1/rooms?limit=100' \\
    -H \"Authorization: Bearer \$TOKEN\" \\
    | jq -r '.rooms[] | \"\(.name)\t\(.room_id)\t\(.canonical_alias // \"no alias\")\t\(.joined_members) members\"'
" | column -t -s $'\t'
