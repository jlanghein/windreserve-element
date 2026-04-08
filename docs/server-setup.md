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

## Installed Software

- Docker 29.4.0
- Docker Compose 5.1.1

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
