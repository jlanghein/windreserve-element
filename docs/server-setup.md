# Server Setup

## Hetzner Cloud VM

| Property | Value |
|----------|-------|
| Hostname | matrix-new |
| IP Address | 91.99.184.79 |
| Type | CX21 (2 vCPU, 4GB RAM, 40GB SSD) |
| OS | Debian 12 |
| Location | Hetzner Cloud |
| Cost | ~€4.85/month |

## DNS Records

| Record | Type | Value | Managed By |
|--------|------|-------|------------|
| `matrix.windreserve.de` | A | 91.99.184.79 | UCS (internal) + Strato (external) |
| `element.windreserve.de` | A | 91.99.184.79 | UCS (internal) + Strato (external) |
| `turn.windreserve.de` | A | 91.99.184.79 | UCS (internal) + Strato (external) |

### DNS Management

**External DNS** is managed via Strato for public internet resolution.

**Internal DNS** is managed via Univention Corporate Server (UCS) at `dc-a.windreserve.de` (10.25.10.43). This is required for WindReserve internal network clients to resolve these domains.

See [UCS DNS Management](#ucs-dns-management) section below for CLI commands.

## Installed Software

- Docker 29.4.0
- Docker Compose 5.1.1
- Git 2.39.5
- jq (for JSON parsing)

## Docker Compose Stack

The stack is deployed at `/root/windreserve-element` on the VM.

### Services

| Service | Image | Purpose | Ports |
|---------|-------|---------|-------|
| **caddy** | caddy:2-alpine | HTTPS reverse proxy, SSL termination | 80, 443 |
| **synapse** | matrixdotorg/synapse:latest | Matrix homeserver | 8008 (internal) |
| **postgres** | postgres:15-alpine | Database for Synapse | 5432 (internal) |
| **coturn** | coturn/coturn:latest | TURN/STUN server for voice/video | 3478, 5349, 49152-49200 |

### Endpoints

| URL | Service |
|-----|---------|
| https://matrix.windreserve.de | Synapse (Matrix API) |
| https://element.windreserve.de | Element Web client |

### Configuration Files

| File | Purpose |
|------|---------|
| `.env` | Environment variables (passwords, domains) |
| `synapse/homeserver.yaml` | Synapse configuration |
| `synapse/log.yaml` | Synapse logging configuration |
| `caddy/Caddyfile` | Caddy reverse proxy rules |
| `coturn/turnserver.conf` | TURN server configuration |
| `element/config.json` | Element Web client configuration |

### Key Configuration Details

- **server_name**: `matrix.windreserve.de` (cannot be changed - all user IDs use this)
- **public_baseurl**: `https://matrix.windreserve.de/`
- **Element default server**: `https://matrix.windreserve.de`
- **TURN server**: `turn.windreserve.de` (for voice/video calls)

### Data Directories

| Path | Purpose |
|------|---------|
| `data/synapse-keys/` | Synapse signing key |
| Docker volume `synapse_media` | Uploaded media files |
| Docker volume `postgres_data` | PostgreSQL database |
| Docker volume `caddy_data` | SSL certificates |

### Common Commands

```bash
# SSH to server
source secrets.env
ssh root@$SERVER_IP

# View running containers
docker compose ps

# View logs
docker compose logs -f synapse
docker compose logs -f caddy

# Restart a service
docker compose restart synapse

# Stop all services
docker compose down

# Start all services
docker compose up -d

# Check Synapse health
curl -s https://matrix.windreserve.de/_matrix/client/versions
```

### Admin Commands

```bash
# Get admin token (run on server)
docker compose exec synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \
    -H "Content-Type: application/json" \
    -d '{"type": "m.login.password", "user": "synapse-admin", "password": "PASSWORD"}'

# Set user password (replace TOKEN and username)
docker compose exec synapse curl -s -X PUT \
    "http://localhost:8008/_synapse/admin/v2/users/@username:matrix.windreserve.de" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer TOKEN" \
    -d '{"password": "new_password"}'

# List users
docker compose exec postgres psql -U synapse -d synapse -c "SELECT name FROM users ORDER BY name;"
```

## Firewall Rules

Configured in Hetzner Cloud Console:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (Caddy) |
| 443 | TCP | HTTPS (Caddy) |
| 3478 | TCP/UDP | TURN |
| 5349 | TCP/UDP | TURNS |
| 49152-49200 | UDP | TURN media relay |

## SSH Access

```bash
# Load IP from secrets
source secrets.env
ssh root@$SERVER_IP
```

## Credential Storage

- **secrets.env** - Server IPs and old server credentials (gitignored)
- **element-secrets.env** - Matrix user passwords and security keys (gitignored)

Both files are listed in `.gitignore` and should never be committed.

## Related Documentation

- [Migration Guide](migration.md) - Full migration process from old server

## TURN Server (Voice/Video Calls)

The coturn TURN server enables voice and video calls between users, especially when they are behind NAT.

### Configuration

Key settings in `coturn/turnserver.conf`:
- `external-ip=91.99.184.79` - Required for NAT traversal
- `static-auth-secret` - Must match Synapse's `turn_shared_secret`
- `realm=turn.windreserve.de`

Synapse settings in `homeserver.yaml`:
```yaml
turn_uris:
  - "turn:turn.windreserve.de:3478?transport=udp"
  - "turn:turn.windreserve.de:3478?transport=tcp"
  - "turns:turn.windreserve.de:5349?transport=tcp"
turn_shared_secret: "SECRET_FROM_ENV"
turn_user_lifetime: 86400000
```

### Deployment Note

The `coturn/turnserver.conf` in the repo contains a placeholder for the secret. On deployment, replace `REPLACE_WITH_TURN_SECRET` with the actual value from `.env` `TURN_SECRET`.

### Testing TURN

```bash
# Check ports are open
nc -zv turn.windreserve.de 3478
nc -zu turn.windreserve.de 3478

# Test in Element: start a voice/video call between two users
```

## Security Hardening

The server has the following security measures in place:

### SSH Security
- Root login: Key-only (`PermitRootLogin prohibit-password`)
- Password authentication: Disabled for root

### Fail2ban
Installed and configured to protect SSH from brute-force attacks:
```bash
# Check status
fail2ban-client status sshd

# View banned IPs
fail2ban-client status sshd | grep "Banned IP"
```

Configuration in `/etc/fail2ban/jail.local`:
- Ban time: 1 hour
- Max retries: 5
- Backend: systemd

### HTTP Security Headers
Both `matrix.windreserve.de` and `element.windreserve.de` include:
- `Strict-Transport-Security` (HSTS)
- `X-Frame-Options`
- `X-Content-Type-Options`
- `X-XSS-Protection`
- `Referrer-Policy`

### Firewall
Hetzner Cloud Firewall (`Firewall-Matrix`) configured with:
- SSH (22/TCP)
- HTTP/HTTPS (80, 443/TCP)
- TURN (3478, 5349 TCP/UDP)
- TURN Media (49152-49200/UDP)

### File Permissions
- `.env` file: `chmod 600` (root only)

### Automatic Updates
- `unattended-upgrades` installed for automatic security updates

## UCS DNS Management

The WindReserve internal network uses Univention Corporate Server (UCS) for DNS. Clients on the internal network (10.25.x.x) resolve domains via the UCS DNS servers.

### UCS Server Details

| Property | Value |
|----------|-------|
| Hostname | dc-a.windreserve.de |
| IP Address | 10.25.10.43 |
| Type | Univention Corporate Server 5.2 |
| Role | Primary DNS server for windreserve.de zone |

### SSH Access

```bash
# Load credentials
source secrets.env
ssh $UCS_USER@$UCS_HOST
```

### DNS CLI Commands

UCS uses `univention-directory-manager` (udm) for DNS management. The full path is `/usr/sbin/univention-directory-manager`.

#### List DNS Zones

```bash
/usr/sbin/univention-directory-manager dns/forward_zone list
```

#### List Host Records

```bash
# List all A records in windreserve.de zone
/usr/sbin/univention-directory-manager dns/host_record list \
  --superordinate "zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de"
```

#### Create Host Record (A Record)

```bash
# Add a new A record
/usr/sbin/univention-directory-manager dns/host_record create \
  --superordinate "zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de" \
  --set name=hostname \
  --set a=192.168.1.100
```

#### Modify Host Record

```bash
# Update an existing A record
/usr/sbin/univention-directory-manager dns/host_record modify \
  --dn "relativeDomainName=hostname,zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de" \
  --set a=192.168.1.101
```

#### Delete Host Record

```bash
# Remove an A record
/usr/sbin/univention-directory-manager dns/host_record remove \
  --dn "relativeDomainName=hostname,zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de"
```

### Matrix/Element DNS Records

The following records were added for internal DNS resolution:

```bash
# matrix.windreserve.de -> 91.99.184.79
/usr/sbin/univention-directory-manager dns/host_record create \
  --superordinate "zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de" \
  --set name=matrix \
  --set a=91.99.184.79

# element.windreserve.de -> 91.99.184.79
/usr/sbin/univention-directory-manager dns/host_record create \
  --superordinate "zoneName=windreserve.de,cn=dns,dc=windreserve,dc=de" \
  --set name=element \
  --set a=91.99.184.79
```

### Verify DNS Resolution

From any internal host (e.g., 10.25.10.104):

```bash
# Check DNS resolution
host matrix.windreserve.de
host element.windreserve.de

# Test HTTPS connectivity
curl -s https://matrix.windreserve.de/_matrix/client/versions
```
