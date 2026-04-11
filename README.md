# WindReserve Element/Matrix Infrastructure

Self-hosted Matrix (Synapse) + Element setup for WindReserve internal communication.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Hetzner Cloud VM (CX21 - 2 vCPU, 4GB RAM, 40GB)                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Docker Compose                                          │   │
│  │                                                         │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐           │   │
│  │  │   Caddy   │  │  Synapse  │  │ PostgreSQL│           │   │
│  │  │   :443    │──│   :8008   │──│   :5432   │           │   │
│  │  └───────────┘  └───────────┘  └───────────┘           │   │
│  │        │                                                │   │
│  │  ┌───────────┐  ┌───────────┐                          │   │
│  │  │  Element  │  │  coturn   │                          │   │
│  │  │  (static) │  │   :3478   │                          │   │
│  │  └───────────┘  └───────────┘                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Domains

- `element-new.windreserve.de` - Element web client
- `matrix-new.windreserve.de` - Synapse homeserver API
- `turn.windreserve.de` - TURN server for voice/video

## Quick Start

```bash
# 1. Copy example env file
cp .env.example .env

# 2. Edit .env with your values
nano .env

# 3. Start services
docker compose up -d

# 4. Check logs
docker compose logs -f
```

## Migration from Old Setup

See [docs/migration.md](docs/migration.md) for migrating from the old oxygen-based setup.

## Directory Structure

```
.
├── docker-compose.yml      # Main compose file
├── .env.example            # Environment variables template
├── caddy/
│   └── Caddyfile          # Caddy reverse proxy config
├── synapse/
│   └── homeserver.yaml    # Synapse configuration
├── element/
│   └── config.json        # Element web client config
├── coturn/
│   └── turnserver.conf    # TURN server config
├── scripts/               # CLI management scripts
│   ├── create-wind-farm-space.sh  # Create space with turbine rooms
│   ├── rename-room.sh             # Rename a room
│   ├── delete-room.sh             # Delete a room
│   ├── create-user.sh             # Create new user
│   ├── add-user-to-room.sh        # Add user to room
│   ├── list-rooms.sh              # List all rooms
│   └── list-users.sh              # List all users
├── docs/
│   ├── cli-commands.md    # CLI reference
│   ├── migration.md       # Migration guide
│   └── server-setup.md    # Server setup guide
└── private/               # Wind farm data (gitignored)
```

## Maintenance

### Backup

```bash
# Database
docker compose exec postgres pg_dump -U synapse synapse > backup.sql

# Media files
tar -czf media-backup.tar.gz ./data/synapse-media
```

### Update

```bash
docker compose pull
docker compose up -d
```

## License

Internal use only - WindReserve GmbH
