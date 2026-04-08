# Migration Guide: Old Synapse to New Setup

This guide covers migrating from the old oxygen-based Matrix setup to the new Hetzner Cloud VM.

## Overview

| Component | Old Location | New Location |
|-----------|-------------|--------------|
| Synapse | VM 306 (10.25.10.64) | Hetzner Cloud VM (91.99.184.79) |
| PostgreSQL | Local on VM 306 | Docker container |
| Element-web | VM 310 (10.25.10.66) | Docker container (static files) |
| Media files | /var/lib/matrix-synapse/media | Docker volume |

## DNS Configuration

**Production URLs (pointing to new server):**

| Record | Type | Value |
|--------|------|-------|
| `matrix.windreserve.de` | A | 91.99.184.79 |
| `element.windreserve.de` | A | 91.99.184.79 |
| `turn.windreserve.de` | A | 91.99.184.79 |

DNS managed via Strato.

## Pre-Migration Checklist

- [x] New Hetzner VM provisioned
- [x] DNS records updated to point to new server
- [x] Docker and docker-compose installed
- [x] Firewall rules configured (80, 443, 3478, 5349)
- [x] Docker Compose stack deployed and verified

## Step 1: Export from Old Server

**Status: COMPLETED** (2026-04-08)

SSH to the old Synapse server (10.25.10.64):

```bash
# Export PostgreSQL database
sudo -u postgres pg_dump synapse > /tmp/synapse_backup.sql

# Copy signing key (CRITICAL - must be exact same key)
sudo cp /etc/matrix-synapse/homeserver.signing.key /tmp/

# Archive media files
sudo tar -czf /tmp/synapse_media.tar.gz -C /var/lib/matrix-synapse media/

# Set permissions for transfer
sudo chmod 644 /tmp/synapse_backup.sql /tmp/homeserver.signing.key /tmp/synapse_media.tar.gz
```

### Exported Files

| File | Size | Description |
|------|------|-------------|
| `/tmp/synapse_backup.sql` | 42 MB | PostgreSQL database (includes all users) |
| `/tmp/homeserver.signing.key` | 59 B | Server signing key (CRITICAL) |
| `/tmp/synapse_media.tar.gz` | 1022 MB | Media files (uploads, avatars, etc.) |

## Step 2: Transfer to New Server

**Status: COMPLETED** (2026-04-08)

```bash
# Transfer files from old server
scp windadmin@10.25.10.64:/tmp/synapse_backup.sql ./
scp windadmin@10.25.10.64:/tmp/homeserver.signing.key ./
scp windadmin@10.25.10.64:/tmp/synapse_media.tar.gz ./
```

## Step 3: Import to New Server

**Status: COMPLETED** (2026-04-08)

On the new Hetzner VM:

```bash
# Start only PostgreSQL first
docker compose up -d postgres
sleep 10

# Drop existing schema and import database
docker compose exec -T postgres psql -U synapse -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
cat synapse_backup.sql | docker compose exec -T postgres psql -U synapse synapse

# Copy signing key
cp homeserver.signing.key data/synapse-keys/signing.key
chown 991:991 data/synapse-keys/signing.key

# Extract media files to docker volume
tar -xzf synapse_media.tar.gz
docker run --rm -v windreserve-element_synapse_media:/data/media_store -v $(pwd)/media:/media alpine \
    sh -c 'cp -r /media/* /data/media_store/ && chown -R 991:991 /data/media_store'

# Start all services
docker compose up -d
```

### Important: server_name Configuration

The `server_name` in homeserver.yaml MUST remain `matrix.windreserve.de` because:
- All existing users have IDs like `@user:matrix.windreserve.de`
- Synapse prevents changing server_name after initial setup
- The server_name is the permanent identity, separate from the serving URL

## Step 4: Verify Migration

**Status: COMPLETED** (2026-04-08)

```bash
# Check Synapse is running
curl -s https://matrix.windreserve.de/_matrix/client/versions

# Check federation
curl -s https://matrix.windreserve.de/.well-known/matrix/server

# Test login via Element
# Open https://element.windreserve.de and try to log in
```

## Step 5: Set Local User Passwords (Replacing LDAP)

**Status: COMPLETED** (2026-04-08)

Since we're not using LDAP anymore, all existing users needed local passwords set.

### Admin Setup

A `synapse-admin` user was created with admin privileges for managing user passwords:

```bash
# Create admin user (already done)
docker compose exec synapse register_new_matrix_user \
    -u synapse-admin -p 'PASSWORD' -a \
    -c /data/homeserver.yaml http://localhost:8008
```

### Setting User Passwords via Admin API

```bash
# Get admin access token
TOKEN=$(docker compose exec synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \
    -H "Content-Type: application/json" \
    -d '{"type": "m.login.password", "user": "synapse-admin", "password": "PASSWORD"}' \
    | jq -r '.access_token')

# Set password for a user
docker compose exec synapse curl -s -X PUT \
    "http://localhost:8008/_synapse/admin/v2/users/@username:matrix.windreserve.de" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"password": "new_password"}'
```

### User Credentials

User credentials are stored in `element-secrets.env` (gitignored). This includes:
- Synapse admin credentials
- Registration shared secret
- Bot account passwords (from Bitwarden)
- User passwords (set as needed)
- Security keys (placeholders for regeneration)

### Security Key / E2EE Recovery

After migration, users may be prompted for their Security Key when logging in. This is for Matrix end-to-end encryption recovery.

Options:
1. **User has Security Key** - Enter it to restore encrypted message history
2. **User lost Security Key** - Click "Reset all" to start fresh (loses old E2EE message history)

## Step 6: Stop Old Server

**Status: COMPLETED** (2026-04-08)

```bash
# SSH to old server and stop Synapse
ssh windadmin@10.25.10.64
sudo systemctl stop matrix-synapse
```

## Rollback Plan

If something goes wrong:
1. Start old Synapse: `sudo systemctl start matrix-synapse`
2. Revert DNS to point to old server

## Post-Migration Status

| Task | Status |
|------|--------|
| Database imported | Completed |
| Media files imported | Completed |
| Signing key copied | Completed |
| DNS cutover | Completed |
| SSL certificates | Completed (Let's Encrypt via Caddy) |
| Old Synapse stopped | Completed |
| User passwords set | Partial (7 users + bots done, 25 pending) |
| TURN server configured | Completed |
| Voice/video calls | Tested and working |

## Endpoints

| URL | Service |
|-----|---------|
| https://matrix.windreserve.de | Synapse (Matrix API) |
| https://element.windreserve.de | Element Web client |
| turn.windreserve.de:3478 | TURN server (UDP/TCP) |
| turn.windreserve.de:5349 | TURNS server (TLS) |

## Next Steps

1. Set passwords for remaining users as needed
2. Decommission old server after verification period (Issue #9)
