# Server Setup

## Hetzner Cloud VM

| Property | Value |
|----------|-------|
| Hostname | matrix-new |
| Type | CX21 (2 vCPU, 4GB RAM, 40GB SSD) |
| OS | Debian 12 |
| Location | Hetzner Cloud |
| Cost | ~€4.85/month |

The IP address is stored in `secrets.env` (not committed to git).

## DNS Records

| Record | Type | Value |
|--------|------|-------|
| `matrix-new.windreserve.de` | A | 91.99.184.79 |
| `element-new.windreserve.de` | A | 91.99.184.79 |
| `turn-new.windreserve.de` | A | 91.99.184.79 |

DNS managed via Strato.

## Installed Software

- Docker 29.4.0
- Docker Compose 5.1.1
- Git 2.39.5

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
| https://matrix-new.windreserve.de | Synapse (Matrix API) |
| https://element-new.windreserve.de | Element Web client |

### Configuration Files

| File | Purpose |
|------|---------|
| `.env` | Environment variables (passwords, domains) |
| `synapse/homeserver.yaml` | Synapse configuration |
| `synapse/log.config` | Synapse logging configuration |
| `caddy/Caddyfile` | Caddy reverse proxy rules |
| `coturn/turnserver.conf` | TURN server configuration |
| `element/config.json` | Element Web client configuration |

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

## Next Steps

See [migration.md](migration.md) for the full migration process.
