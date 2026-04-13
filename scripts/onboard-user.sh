#!/bin/bash
# Onboard a new Matrix user with full access to wind farm spaces and WR rooms
# Usage: ./onboard-user.sh <username> <password> <first_name> <last_name>
#
# This script:
# 1. Creates the user with password
# 2. Sets display name (first + last name)
# 3. Adds user to all wind farm spaces and rooms
# 4. Adds user to WR space and rooms (except IT Crew)
# 5. Saves password to element-secrets.env
# 6. Updates profile via client API to propagate displayname

set -e

if [ $# -lt 4 ]; then
    echo "Usage: $0 <username> <password> <first_name> <last_name>"
    echo "Example: $0 t.witte 'MyPassword123' 'Tobias' 'Witte'"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"
FIRST_NAME="$3"
LAST_NAME="$4"
DISPLAY_NAME="$FIRST_NAME $LAST_NAME"

# Load secrets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../secrets.env"

# Read admin credentials from element-secrets.env
SYNAPSE_ADMIN_USER=$(grep '^SYNAPSE_ADMIN_USER=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)
SYNAPSE_ADMIN_PASS=$(grep '^SYNAPSE_ADMIN_PASS=' "$SCRIPT_DIR/../element-secrets.env" | cut -d'=' -f2)

echo "=== Onboarding user: $USERNAME ($DISPLAY_NAME) ==="
echo ""

# Step 1: Create user
echo "Step 1: Creating user..."
ssh root@$SERVER_IP "
cd /root/windreserve-element

# Register the user
docker compose exec -T synapse register_new_matrix_user \\
    -c /data/homeserver.yaml \\
    -u '$USERNAME' \\
    -p '$PASSWORD' \\
    --no-admin \\
    http://localhost:8008 2>/dev/null || echo 'User may already exist, continuing...'
"

# Step 2: Set display name via admin API
echo "Step 2: Setting display name..."
ssh root@$SERVER_IP "
cd /root/windreserve-element

TOKEN=\$(docker compose exec -T synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \\
    -H 'Content-Type: application/json' \\
    -d '{\"type\": \"m.login.password\", \"user\": \"$SYNAPSE_ADMIN_USER\", \"password\": \"$SYNAPSE_ADMIN_PASS\"}' \\
    | jq -r '.access_token')

docker compose exec -T synapse curl -s -X PUT \\
    \"http://localhost:8008/_synapse/admin/v2/users/@$USERNAME:matrix.windreserve.de\" \\
    -H 'Content-Type: application/json' \\
    -H \"Authorization: Bearer \$TOKEN\" \\
    -d '{\"displayname\": \"$DISPLAY_NAME\"}' > /dev/null
"

# Step 3: Add to WR space and rooms (except IT Crew)
echo "Step 3: Adding to WR space and rooms..."

# WR Space
WR_ROOMS=(
    "!SESmjVmEPFzVmzvzUH:matrix.windreserve.de"  # WR Space
    "!xRqgUseDmVmggAjfkp:matrix.windreserve.de"  # Unternehmenschat
    "!MARodRIPCQlQUnykmD:matrix.windreserve.de"  # Fernüberwachung
    "!JqrANXftNVtvCdrwky:matrix.windreserve.de"  # Fernüberwachung - Fehlermeldungen
    # IT Crew excluded: !zWlZPxuxtPiWuUgdFU:matrix.windreserve.de
)

for ROOM in "${WR_ROOMS[@]}"; do
    "$SCRIPT_DIR/add-user-to-room.sh" "$USERNAME" "$ROOM" 2>/dev/null | grep -E "(room_id|errcode)" || true
done

# Step 4: Add to all wind farm spaces and rooms
echo "Step 4: Adding to wind farm spaces and rooms..."

# Wind Farm Spaces and Rooms (extracted from docs/wind-farm-spaces.md)
WIND_FARM_ROOMS=(
    # Badel 2b
    "!UKcBOSDqDrpTDSgqNU:matrix.windreserve.de"
    "!NqlWVLFuWKMyQSyKAo:matrix.windreserve.de"
    "!rkZcKdoXRGnPcqlJzw:matrix.windreserve.de"
    "!UuOUYmuYeLpBdwSMej:matrix.windreserve.de"
    "!WsnmUsEIpkCvSGwmHI:matrix.windreserve.de"
    "!LgsgsluueAJevPttvj:matrix.windreserve.de"
    # Boddin
    "!JolmkGPegNnHOWyePy:matrix.windreserve.de"
    "!RtaivLvudkSoPPMulW:matrix.windreserve.de"
    "!SQqWBcnerkrXAWzPKL:matrix.windreserve.de"
    "!ToklfkyRfcDQISQgGh:matrix.windreserve.de"
    "!uYQSTGNFCfQqRWHbnm:matrix.windreserve.de"
    "!pSTiGnolNBFMROCWql:matrix.windreserve.de"
    "!BNhYWiUxHkHHYnzcrh:matrix.windreserve.de"
    # Buchholz-Birkstücke
    "!ITkJSbohbmMRCsKgoD:matrix.windreserve.de"
    "!VrafuKUEzlkvBUuMVr:matrix.windreserve.de"
    "!pPrCrfmlWkpSTfHsuX:matrix.windreserve.de"
    "!mvGTjfWqSuPrHydzbt:matrix.windreserve.de"
    # Dorndorf
    "!gyUQKVsJNjqffZNxCK:matrix.windreserve.de"
    "!DixeBgNlndDRMZSMxj:matrix.windreserve.de"
    # Flechtdorf-Helmscheidt
    "!sVKIrWVgKJGpKsPcCz:matrix.windreserve.de"
    "!ZmNfRUzPKNbgzrxoID:matrix.windreserve.de"
    "!PZwNjtrJxvagCmmdqR:matrix.windreserve.de"
    "!buhbWPBJYLnQalzICy:matrix.windreserve.de"
    "!eweerFGuYThtjYGtjS:matrix.windreserve.de"
    "!UsObkflhLBxoNEjnDt:matrix.windreserve.de"
    "!timsSjZXUVqbxxPhsX:matrix.windreserve.de"
    "!peASDaCyYjSsRaBOFC:matrix.windreserve.de"
    "!SUcuBCkkFgoRbTEJqk:matrix.windreserve.de"
    # Frehne Nord
    "!woUIkHVRLLQKyNVBhH:matrix.windreserve.de"
    "!MuXxllaXRynximdUNH:matrix.windreserve.de"
    # Frehne West
    "!OHEMtgXFjnfDKTSDBe:matrix.windreserve.de"
    "!MELaDzDBpHYrnytvUl:matrix.windreserve.de"
    "!VaXRtZvuIHJRHXdKpn:matrix.windreserve.de"
    "!EXZCEerdWCVdUPKMoP:matrix.windreserve.de"
    "!TwPbxhIYFafLDTszgZ:matrix.windreserve.de"
    # Giersleben
    "!tyVfEJzJrlgbkRgshA:matrix.windreserve.de"
    "!uSgNcndXgkkhgCJTaj:matrix.windreserve.de"
    "!sKWPOIJkhXpSsRcUaY:matrix.windreserve.de"
    "!vUzVGYgwLjnGKAoHac:matrix.windreserve.de"
    "!ZlIIYNHFlWmfIvFAFQ:matrix.windreserve.de"
    "!NGUjfEsDoLKnSQayuI:matrix.windreserve.de"
    "!JArFLuZJaCVrRbyMwa:matrix.windreserve.de"
    "!zofTgeoTRwOXeCbLuf:matrix.windreserve.de"
    "!nkjZHSZlIowDIXrVra:matrix.windreserve.de"
    "!xgqPiEyjUZLTelmFSS:matrix.windreserve.de"
    "!UxWfLfQICrleGygMRl:matrix.windreserve.de"
    "!btgxXxdpPsNqIgHSfO:matrix.windreserve.de"
    "!FRqeTokGJfTcjeMIwx:matrix.windreserve.de"
    "!wLVnCglSQaJhQKVFin:matrix.windreserve.de"
    "!dAlqUFhaxubqFRikvK:matrix.windreserve.de"
    "!lIqcvmXfxacjNmEGbO:matrix.windreserve.de"
    "!EAhaOyJOkneKLfuliV:matrix.windreserve.de"
    # Hanstedt 2
    "!UaNESrgbzUNKsziFTV:matrix.windreserve.de"
    "!OMwzIYZPKOMNamjNSS:matrix.windreserve.de"
    "!JeIIMdExBEETFCRLYl:matrix.windreserve.de"
    "!AlWzTXxhHGjaDikzyy:matrix.windreserve.de"
    "!GOWcYtmtnDlgSsImHI:matrix.windreserve.de"
    "!QTtFDZBwpWSnJwyYTn:matrix.windreserve.de"
    "!xHRcTmceWveHmOziqx:matrix.windreserve.de"
    "!ltqpPAWEoHTIrsiQzF:matrix.windreserve.de"
    # Ohlenbüttel
    "!OCPhxpgTRVLxyOKeav:matrix.windreserve.de"
    "!inpQcnfluZxbgWtQfa:matrix.windreserve.de"
    "!PrpYScMRmViRhOqbnQ:matrix.windreserve.de"
    "!qrOcOqNoRTxnIBCMZA:matrix.windreserve.de"
    "!HZXOVPudBFNHNwdrbU:matrix.windreserve.de"
    "!AYAVOuZNxtoesuwSpo:matrix.windreserve.de"
    "!NUaHHSPgCjIwtedPTC:matrix.windreserve.de"
    # Oschersleben
    "!HjxbvxgxGOdjealCHz:matrix.windreserve.de"
    "!RdkRFxfTUKMQxMTLTl:matrix.windreserve.de"
    "!SlGxGOBEzPUpqVZSnN:matrix.windreserve.de"
    # Quenstedt
    "!GPIcZRDrVorhhPqQeQ:matrix.windreserve.de"
    "!lJXwgXlfbsyRbzLVlt:matrix.windreserve.de"
    "!aUfVlQBWNNVLawHdbt:matrix.windreserve.de"
    "!UOxQOBgqrfoqemqHPa:matrix.windreserve.de"
    "!UcjecFmCHVjMbBIInV:matrix.windreserve.de"
    "!wNpJIhbRWtrurOmDfK:matrix.windreserve.de"
    # Schlagsülsdorf
    "!rpIwnHpQRWOSXMQJpq:matrix.windreserve.de"
    "!NsNRqNISHAewdfSdHx:matrix.windreserve.de"
    # Schrepkow-Kletzke
    "!zKaCTNrOKQWeKUYhiC:matrix.windreserve.de"
    "!GGJqOZFmApUwtXlZQo:matrix.windreserve.de"
    "!bfzmwxPRDUGPIJLYxD:matrix.windreserve.de"
    "!SmSmDwTNyBSQoxCEzF:matrix.windreserve.de"
    # Silmersdorf
    "!ihkeyOCDwkrUADhYij:matrix.windreserve.de"
    "!pcFHujFPcAYaslZDZx:matrix.windreserve.de"
    "!YtWkVtZTfXMcMNNacc:matrix.windreserve.de"
    "!fvyKgLVhzMwnAxiZHQ:matrix.windreserve.de"
    "!ciGWSnheJTIrgaabZU:matrix.windreserve.de"
    "!KRWukplpyZOhPFDwzT:matrix.windreserve.de"
    "!pUqGdFeCvOaaBZjMbA:matrix.windreserve.de"
    "!DJkGMsTxJRjjhyPUGQ:matrix.windreserve.de"
    "!MKVqBiHPcAkFMdEIBp:matrix.windreserve.de"
    "!JnmgfDozjRBupTlAfe:matrix.windreserve.de"
    # Tangendorf
    "!KlpKhRrUDuAEuoqBXK:matrix.windreserve.de"
    "!IVfOqrGEocaOgArctk:matrix.windreserve.de"
    "!GyEFysZHkYeyAXvTwr:matrix.windreserve.de"
    "!gzWoiHBHifbvsxtUfp:matrix.windreserve.de"
    # Trinwillershagen
    "!marRLjGLLdGubyBhop:matrix.windreserve.de"
    "!KrweLfvquoKukXkFWi:matrix.windreserve.de"
    "!KqkySzWMZoGBWdzftn:matrix.windreserve.de"
    "!YEpEleRhBGvvietBiU:matrix.windreserve.de"
    "!cKwCxnvCArZMHoccSU:matrix.windreserve.de"
    "!HXkPSgJwaDVuYmLhrN:matrix.windreserve.de"
    "!ihkecomAatKXmIobib:matrix.windreserve.de"
    "!NppLedmJblFDpVTXoM:matrix.windreserve.de"
    "!HhmKXvCXYIyIBZZziK:matrix.windreserve.de"
    "!pcUcpUkOGvKuzUCmEQ:matrix.windreserve.de"
    "!JjzncqcqzKfYQMQedj:matrix.windreserve.de"
    "!uwdeZUdoUYQxFuarmc:matrix.windreserve.de"
    "!lzoqkIlIjcNMbrKTnW:matrix.windreserve.de"
    "!TcBkOPUbmXMWsaflTU:matrix.windreserve.de"
    "!dlqyhNadJjvFndhZRt:matrix.windreserve.de"
    "!jRedXnwWkeTRDOgZEz:matrix.windreserve.de"
    "!MCHziQcNxvaXsVBxKT:matrix.windreserve.de"
    "!zcSibsAbnVsDpHWlGR:matrix.windreserve.de"
    "!YASlINxvxcrejSuKAP:matrix.windreserve.de"
    # Vahlbruch
    "!dOwgqhFZBobUkMYaln:matrix.windreserve.de"
    "!hRyETiooTuoUaYRynu:matrix.windreserve.de"
    "!RlnrGzFpGXUjczZvCS:matrix.windreserve.de"
    "!ncchowsTLvuzeNNaHw:matrix.windreserve.de"
    "!hNAvuoSkWADOpEEVey:matrix.windreserve.de"
    # Woltersdorf
    "!sWUCxBJGqLxKYoVUXN:matrix.windreserve.de"
    "!hIipzdWQdYoBaLPPtJ:matrix.windreserve.de"
    # Zölkow
    "!ZQGdifJYRsfvvOUFtS:matrix.windreserve.de"
    "!LECPWRWEHhJeLsTQBj:matrix.windreserve.de"
    "!biGnljwZRGAbIsXkQq:matrix.windreserve.de"
)

for ROOM in "${WIND_FARM_ROOMS[@]}"; do
    "$SCRIPT_DIR/add-user-to-room.sh" "$USERNAME" "$ROOM" 2>/dev/null | grep -E "(room_id|errcode)" || true
done

# Step 5: Update profile via client API to propagate displayname to room memberships
echo "Step 5: Propagating display name to room memberships..."
ssh root@$SERVER_IP "
cd /root/windreserve-element

USER_TOKEN=\$(docker compose exec -T synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \\
    -H 'Content-Type: application/json' \\
    -d '{\"type\": \"m.login.password\", \"user\": \"$USERNAME\", \"password\": \"$PASSWORD\"}' \\
    | jq -r '.access_token')

docker compose exec -T synapse curl -s -X PUT \\
    \"http://localhost:8008/_matrix/client/v3/profile/@$USERNAME:matrix.windreserve.de/displayname\" \\
    -H 'Content-Type: application/json' \\
    -H \"Authorization: Bearer \$USER_TOKEN\" \\
    -d '{\"displayname\": \"$DISPLAY_NAME\"}'
"

# Step 6: Save to element-secrets.env
echo ""
echo "Step 6: Saving credentials to element-secrets.env..."

# Check if user already exists in file
if grep -q "^$USERNAME=" "$SCRIPT_DIR/../element-secrets.env"; then
    # Update existing entry
    sed -i "s/^$USERNAME=.*/$USERNAME=$PASSWORD/" "$SCRIPT_DIR/../element-secrets.env"
    echo "Updated existing password entry"
else
    # Add new entry
    echo "" >> "$SCRIPT_DIR/../element-secrets.env"
    echo "# $DISPLAY_NAME" >> "$SCRIPT_DIR/../element-secrets.env"
    echo "$USERNAME=$PASSWORD" >> "$SCRIPT_DIR/../element-secrets.env"
    echo "${USERNAME}_security_key=PLACEHOLDER" >> "$SCRIPT_DIR/../element-secrets.env"
    echo "Added new credentials entry"
fi

echo ""
echo "=========================================="
echo "=== User onboarding complete! ==="
echo "=========================================="
echo ""
echo "Username: $USERNAME"
echo "Display Name: $DISPLAY_NAME"
echo "Password: $PASSWORD"
echo ""
echo "The user has been added to:"
echo "  - WR Space and rooms (except IT Crew)"
echo "  - All wind farm spaces and rooms"
echo ""
echo "Note: Some rooms may have failed if synapse-admin is not a member."
echo "Security key is set to PLACEHOLDER - update after user sets up E2EE."
