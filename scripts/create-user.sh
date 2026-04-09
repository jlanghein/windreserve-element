#!/bin/bash
# Create a new Matrix user with display name
# Usage: ./create-user.sh <username> <password> <display_name>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <username> <password> <display_name>"
    echo "Example: $0 s.conradi 'MyPassword123' 'Stefan Conradi'"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"
DISPLAY_NAME="$3"

# Load secrets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env"

# Read admin credentials from element-secrets.env
SYNAPSE_ADMIN_USER=$(grep '^SYNAPSE_ADMIN_USER=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)
SYNAPSE_ADMIN_PASS=$(grep '^SYNAPSE_ADMIN_PASS=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)

echo "=== Creating user: $USERNAME ==="

# Create user via SSH
ssh root@$SERVER_IP "
cd /root/windreserve-element

# Register the user
docker compose exec -T synapse register_new_matrix_user \\
    -c /data/homeserver.yaml \\
    -u '$USERNAME' \\
    -p '$PASSWORD' \\
    --no-admin \\
    http://localhost:8008

# Get admin token
TOKEN=\$(docker compose exec -T synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \\
    -H 'Content-Type: application/json' \\
    -d '{\"type\": \"m.login.password\", \"user\": \"$SYNAPSE_ADMIN_USER\", \"password\": \"$SYNAPSE_ADMIN_PASS\"}' \\
    | jq -r '.access_token')

# Set display name
docker compose exec -T synapse curl -s -X PUT \\
    \"http://localhost:8008/_synapse/admin/v2/users/@$USERNAME:matrix.windreserve.de\" \\
    -H 'Content-Type: application/json' \\
    -H \"Authorization: Bearer \$TOKEN\" \\
    -d '{\"displayname\": \"$DISPLAY_NAME\"}' | jq .
"

echo ""
echo "=== User created successfully ==="
echo "Username: $USERNAME"
echo "Display Name: $DISPLAY_NAME"
echo ""
echo "Don't forget to add credentials to element-secrets.env:"
echo "$USERNAME=$PASSWORD"
echo "${USERNAME}_security_key=PLACEHOLDER"
