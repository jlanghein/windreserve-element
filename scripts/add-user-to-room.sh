#!/bin/bash
# Add a user to a Matrix room
# Usage: ./add-user-to-room.sh <username> <room_id_or_alias>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <room_id_or_alias>"
    echo ""
    echo "Examples:"
    echo "  $0 s.conradi '!xRqgUseDmVmggAjfkp:matrix.windreserve.de'"
    echo "  $0 s.conradi '#uc:matrix.windreserve.de'"
    echo ""
    echo "Common rooms:"
    echo "  Unternehmenschat: !xRqgUseDmVmggAjfkp:matrix.windreserve.de (#uc)"
    echo ""
    echo "Run ./list-rooms.sh to see all available rooms"
    exit 1
fi

USERNAME="$1"
ROOM="$2"

# Load secrets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env"

# Read admin credentials from element-secrets.env
SYNAPSE_ADMIN_USER=$(grep '^SYNAPSE_ADMIN_USER=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)
SYNAPSE_ADMIN_PASS=$(grep '^SYNAPSE_ADMIN_PASS=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)

echo "=== Adding $USERNAME to room $ROOM ==="

ssh root@$SERVER_IP "
cd /root/windreserve-element

# Get admin token
TOKEN=\$(docker compose exec -T synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \\
    -H 'Content-Type: application/json' \\
    -d '{\"type\": \"m.login.password\", \"user\": \"$SYNAPSE_ADMIN_USER\", \"password\": \"$SYNAPSE_ADMIN_PASS\"}' \\
    | jq -r '.access_token')

# Join user to room
docker compose exec -T synapse curl -s -X POST \\
    \"http://localhost:8008/_synapse/admin/v1/join/$ROOM\" \\
    -H 'Content-Type: application/json' \\
    -H \"Authorization: Bearer \$TOKEN\" \\
    -d '{\"user_id\": \"@$USERNAME:matrix.windreserve.de\"}' | jq .
"

echo ""
echo "=== User $USERNAME added to room ==="
