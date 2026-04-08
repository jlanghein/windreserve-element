# Migration Guide: Old Synapse to New Setup

This guide covers migrating from the old oxygen-based Matrix setup to the new Hetzner Cloud VM.

## Overview

| Component | Old Location | New Location |
|-----------|-------------|--------------|
| Synapse | VM 306 (10.25.10.64) | Hetzner Cloud VM |
| PostgreSQL | Local on VM 306 | Docker container |
| Element-web | VM 310 (10.25.10.66) | Docker volume |
| Media files | /var/lib/matrix-synapse/media | Docker volume |

## Pre-Migration Checklist

- [x] New Hetzner VM provisioned
- [x] DNS records created (matrix-new, element-new, turn-new) → 91.99.184.79
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

**Note:** The database export includes all Matrix user accounts. Since we're moving away from LDAP, existing users will need new local passwords set after migration.

## Step 2: Transfer to New Server

**Status: COMPLETED** (2026-04-08)

From your local machine or new server:

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

The `server_name` in homeserver.yaml MUST remain `matrix.windreserve.de` (not `matrix-new.windreserve.de`) because:
- All existing users have IDs like `@user:matrix.windreserve.de`
- Synapse prevents changing server_name after initial setup
- The server_name is the permanent identity, separate from the serving URL

## Step 4: Verify Migration

```bash
# Check Synapse is running
curl -s https://matrix-new.windreserve.de/_matrix/client/versions

# Check federation
curl -s https://matrix-new.windreserve.de/.well-known/matrix/server

# Test login via Element
# Open https://element-new.windreserve.de and try to log in
```

## Step 5: Create Local Users (Replacing LDAP)

Since we're not using LDAP anymore, create local accounts:

```bash
# Register a new user
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u USERNAME \
    -p PASSWORD \
    -a  # -a for admin, omit for regular user

# Or use the admin API to create users
curl -X PUT "https://matrix-new.windreserve.de/_synapse/admin/v2/users/@username:matrix-new.windreserve.de" \
    -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"password": "new_password", "displayname": "Display Name"}'
```

## Step 6: DNS Cutover

Once verified, update DNS:

1. Point `matrix.windreserve.de` → new VM IP
2. Point `element.windreserve.de` → new VM IP
3. Update `config.json` and `homeserver.yaml` to use final domain names
4. Restart services: `docker compose restart`

## Rollback Plan

If something goes wrong:

1. DNS is still pointing to old setup (matrix-new is separate)
2. Old VMs are still running
3. Simply don't proceed with DNS cutover

## Post-Migration Cleanup

After successful migration and verification:

1. Stop old Synapse VM (306)
2. Stop old Element-web VM (310)
3. Archive/delete old VMs after 1 week of stable operation
4. Update HAProxy on opn.nue to remove old backends
