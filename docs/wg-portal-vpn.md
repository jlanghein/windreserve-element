# WireGuard Portal (wg-portal) - VPN Management

This document describes how to access and manage VPN users via the WireGuard Portal (wg-portal) system.

## Overview

WindReserve uses [wg-portal](https://github.com/h44z/wg-portal) (v2.x) for managing WireGuard VPN connections. The portal provides both a web UI and a REST API for peer management.

## Access Information

### Web UI

| Property | Value |
|----------|-------|
| External URL | `https://vpn.windreserve.de` |
| Internal URL | `http://10.21.254.2:8888` |
| Version | v2.0.3 |

**Note:** The external URL is restricted to IT VPN IPs (`10.21.16.0/24`) and select internal networks. Access from the regular employee VPN (`10.21.15.0/24`) is not permitted.

### Alternative Access

If you cannot access the web UI directly, you can:
1. SSH to `caddy.helium` (10.24.0.29) and use curl to interact with the internal API
2. Connect via the IT VPN profile

## WireGuard Interfaces

The system manages two WireGuard interfaces:

### wg0 - MA VPN (Employee VPN)

| Property | Value |
|----------|-------|
| Endpoint | `ma.vpn.windreserve.de:51820` |
| Network | `10.21.15.0/24` |
| Listen Port | 51820 |
| Allowed IPs | `10.21.15.0/24`, `10.24.0.0/16`, `10.25.0.0/16` |
| DNS Servers | `10.25.10.43`, `10.25.10.46`, `1.1.1.1` |

### wg1 - IT VPN

| Property | Value |
|----------|-------|
| Endpoint | `it.vpn.windreserve.de:51821` |
| Network | `10.21.16.0/24` |
| Listen Port | 51821 |
| Allowed IPs | `10.20.0.0/14`, `10.24.0.0/15`, `10.25.0.0/16`, `10.30.15.0/24`, `10.153.15.0/24`, `192.168.0.0/23`, `192.168.188.0/24` |

## REST API

### Authentication

All API requests require authentication via session cookie.

#### Login

```bash
curl -s -i -X POST http://10.21.254.2:8888/api/v0/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<email>","password":"<password>"}'
```

Extract the `wgPortalSession` cookie from the `Set-Cookie` header for subsequent requests.

**Response:**
```json
{
  "Identifier": "user@example.com",
  "Email": "user@example.com",
  "IsAdmin": true,
  "Firstname": "...",
  "Lastname": "...",
  "LinkedPeerCount": 7
}
```

### URL Encoding

**Important:** Interface and peer identifiers in URL paths must be **Base64 URL encoded** (RFC 4648):
- Use `-` instead of `+`
- Use `_` instead of `/`
- Remove padding `=`

Example encoding in bash:
```bash
IFACE=$(printf "wg0" | base64 -w0 | tr "+/" "-_" | tr -d "=")
# Result: d2cw
```

### Endpoints

#### List All Interfaces

```bash
curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/interface/all"
```

#### List All Peers for Interface

```bash
IFACE=$(printf "wg0" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/iface/${IFACE}/all"
```

#### Prepare New Peer (Get Defaults)

Returns a new peer template with auto-generated keys and the next available IP address.

```bash
IFACE=$(printf "wg0" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/iface/${IFACE}/prepare"
```

**Response:**
```json
{
  "Identifier": "<public_key>",
  "DisplayName": "Peer <short_id>",
  "UserIdentifier": "<current_user_email>",
  "InterfaceIdentifier": "wg0",
  "Disabled": false,
  "PrivateKey": "<generated_private_key>",
  "PublicKey": "<generated_public_key>",
  "PresharedKey": "<generated_psk>",
  "Addresses": ["10.21.15.XX/32"],
  "Endpoint": {"Value": "ma.vpn.windreserve.de:51820", "Overridable": true},
  "Dns": {"Value": ["10.25.10.43", "10.25.10.46", "1.1.1.1"], "Overridable": true},
  "PersistentKeepalive": {"Value": 25, "Overridable": true},
  "Filename": "Peer_XXXXX.conf"
}
```

#### Create New Peer

1. First call the `prepare` endpoint to get a template
2. Modify the template as needed (e.g., `DisplayName`, `UserIdentifier`)
3. POST the modified JSON to create the peer

```bash
IFACE=$(printf "wg0" | base64 -w0 | tr "+/" "-_" | tr -d "=")

# Get template
PEER_DATA=$(curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/iface/${IFACE}/prepare")

# Modify DisplayName (example using jq)
PEER_DATA=$(echo "$PEER_DATA" | jq '.DisplayName = "New Employee VPN"')

# Create peer
curl -s -X POST \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/iface/${IFACE}/new" \
  -d "$PEER_DATA"
```

#### Get Single Peer

```bash
PEER_ID=$(printf "<peer_public_key>" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/${PEER_ID}"
```

#### Update Peer

```bash
PEER_ID=$(printf "<peer_public_key>" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -X PUT \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/${PEER_ID}" \
  -d '<peer_json>'
```

#### Delete Peer

```bash
PEER_ID=$(printf "<peer_public_key>" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -X DELETE \
  -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/${PEER_ID}"
```

#### Get Peer Configuration (wg-quick format)

```bash
PEER_ID=$(printf "<peer_public_key>" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/config/${PEER_ID}"
```

Optional query parameter: `?style=wg-quick` (default) or `?style=raw`

#### Get Peer QR Code

```bash
PEER_ID=$(printf "<peer_public_key>" | base64 -w0 | tr "+/" "-_" | tr -d "=")

curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/peer/config-qr/${PEER_ID}" \
  --output qrcode.png
```

#### Send Peer Config via Email

```bash
curl -s -X POST \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/config-mail" \
  -d '{"Identifiers": ["<peer_id_1>", "<peer_id_2>"], "LinkOnly": false}'
```

#### Bulk Operations

**Bulk Delete:**
```bash
curl -s -X POST \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/bulk-delete" \
  -d '{"Identifiers": ["<peer_id_1>", "<peer_id_2>"]}'
```

**Bulk Enable:**
```bash
curl -s -X POST \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/bulk-enable" \
  -d '{"Identifiers": ["<peer_id_1>", "<peer_id_2>"]}'
```

**Bulk Disable:**
```bash
curl -s -X POST \
  -H "Cookie: wgPortalSession=<session>" \
  -H "Content-Type: application/json" \
  "http://10.21.254.2:8888/api/v0/peer/bulk-disable" \
  -d '{"Identifiers": ["<peer_id_1>", "<peer_id_2>"]}'
```

### User Management

#### List All Users

```bash
curl -s -H "Cookie: wgPortalSession=<session>" \
  "http://10.21.254.2:8888/api/v0/user/all"
```

## Complete Example: Create VPN Peer via API

This script creates a new VPN peer for an employee:

```bash
#!/bin/bash

# Configuration
API_URL="http://10.21.254.2:8888"
USERNAME="<admin_email>"
PASSWORD="<admin_password>"
INTERFACE="wg0"
NEW_PEER_NAME="Employee Name - Device"
NEW_PEER_USER="employee@windreserve.de"

# Login and extract session
RESPONSE=$(curl -s -i -X POST "${API_URL}/api/v0/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")

SESSION=$(echo "$RESPONSE" | grep -i "set-cookie:" | \
  sed "s/.*wgPortalSession=\([^;]*\).*/\1/" | tr -d "\r")

if [ -z "$SESSION" ]; then
  echo "Login failed"
  exit 1
fi

# Base64 URL encode interface
IFACE=$(printf "$INTERFACE" | base64 -w0 | tr "+/" "-_" | tr -d "=")

# Prepare peer template
PEER_DATA=$(curl -s -H "Cookie: wgPortalSession=$SESSION" \
  "${API_URL}/api/v0/peer/iface/${IFACE}/prepare")

# Modify peer data
PEER_DATA=$(echo "$PEER_DATA" | \
  sed "s/\"DisplayName\":\"[^\"]*\"/\"DisplayName\":\"${NEW_PEER_NAME}\"/" | \
  sed "s/\"UserIdentifier\":\"[^\"]*\"/\"UserIdentifier\":\"${NEW_PEER_USER}\"/")

# Create peer
RESULT=$(curl -s -X POST \
  -H "Cookie: wgPortalSession=$SESSION" \
  -H "Content-Type: application/json" \
  "${API_URL}/api/v0/peer/iface/${IFACE}/new" \
  -d "$PEER_DATA")

echo "Created peer:"
echo "$RESULT" | jq '{DisplayName, PublicKey, Addresses, UserIdentifier}'

# Extract peer ID for config download
PEER_PUBLIC_KEY=$(echo "$RESULT" | jq -r '.PublicKey')
PEER_ID=$(printf "$PEER_PUBLIC_KEY" | base64 -w0 | tr "+/" "-_" | tr -d "=")

# Get configuration
echo ""
echo "WireGuard Configuration:"
curl -s -H "Cookie: wgPortalSession=$SESSION" \
  "${API_URL}/api/v0/peer/config/${PEER_ID}"
```

## Infrastructure

### Network Topology

```
Internet
    |
    v
[Hetzner Cloud]
    |
    +-- vpn.windreserve.de (Caddy reverse proxy)
    |       |
    |       +-- 10.24.0.29 (caddy.helium)
    |               |
    |               v
    +-- 10.21.254.2:8888 (wg-portal)
            |
            +-- wg0 (MA VPN) - 10.21.15.0/24
            +-- wg1 (IT VPN) - 10.21.16.0/24
```

### Related Systems

| System | IP | Purpose |
|--------|-----|---------|
| wg-portal | 10.21.254.2 | VPN management portal |
| Caddy (Helium) | 10.24.0.29 | Reverse proxy for external access |
| DNS Server 1 | 10.25.10.43 | UCS Domain Controller (dc-a) |
| DNS Server 2 | 10.25.10.46 | Secondary DNS |

## Troubleshooting

### Cannot Access vpn.windreserve.de

The external URL is restricted to specific IP ranges. Check:
1. Are you connected to the IT VPN (`10.21.16.0/24`)?
2. Access via SSH tunnel through `caddy.helium` as an alternative

### API Returns 400 Bad Request

- Ensure interface/peer IDs are properly Base64 URL encoded
- Check that the session cookie is valid and not expired
- Verify the JSON payload is valid

### Peer Creation Fails

- The user must exist in the system (check `/api/v0/user/all`)
- Interface must be valid and active
- IP address pool may be exhausted

## References

- [wg-portal GitHub Repository](https://github.com/h44z/wg-portal)
- [wg-portal Documentation](https://wgportal.org)
- [WireGuard Official Site](https://www.wireguard.com)
