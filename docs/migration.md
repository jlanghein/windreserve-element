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

## Step 2: Transfer to New Server

From your local machine or new server:

```bash
# Transfer files from old server
scp windadmin@10.25.10.64:/tmp/synapse_backup.sql ./
scp windadmin@10.25.10.64:/tmp/homeserver.signing.key ./
scp windadmin@10.25.10.64:/tmp/synapse_media.tar.gz ./
```

## Step 3: Import to New Server

On the new Hetzner VM:

```bash
# Start only PostgreSQL first
docker compose up -d postgres
sleep 10

# Import database
cat synapse_backup.sql | docker compose exec -T postgres psql -U synapse synapse

# Copy signing key to synapse volume
docker compose run --rm -v $(pwd)/homeserver.signing.key:/tmp/signing.key synapse \
    cp /tmp/signing.key /data/keys/signing.key

# Extract media files
mkdir -p ./data/synapse-media
tar -xzf synapse_media.tar.gz -C ./data/synapse-media --strip-components=1

# Start all services
docker compose up -d
```

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
