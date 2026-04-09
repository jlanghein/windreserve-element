# CLI Commands Reference

Quick reference for common administrative tasks on the Matrix/Synapse server.

## Local Scripts

Helper scripts are available in the `scripts/` directory. Run from the project root.

### Create User

Creates a new Matrix user with a display name.

```bash
./scripts/create-user.sh <username> <password> <display_name>

# Example
./scripts/create-user.sh s.conradi 's!4-czhTxFjZrJK' 'Stefan Conradi'
```

After creating a user, add their credentials to `element-secrets.env`:
```
username=password
username_security_key=PLACEHOLDER
```

### Add User to Room

Adds an existing user to a Matrix room.

```bash
./scripts/add-user-to-room.sh <username> <room_id>

# Example - add to Unternehmenschat
./scripts/add-user-to-room.sh s.conradi '!xRqgUseDmVmggAjfkp:matrix.windreserve.de'
```

Common room IDs are defined in `element-secrets.env` as `ROOM_*` variables.

### List Rooms

Lists all rooms with their IDs and member counts.

```bash
./scripts/list-rooms.sh
```

### List Users

Lists all users with their display names.

```bash
./scripts/list-users.sh
```

## SSH Access

```bash
# Load server IP from secrets
source secrets.env
ssh root@$SERVER_IP

# Or directly
ssh root@91.99.184.79
```

## Docker Compose

All commands run from `/root/windreserve-element` on the server.

```bash
# View running containers
docker compose ps

# View logs (follow mode)
docker compose logs -f synapse
docker compose logs -f caddy
docker compose logs -f coturn
docker compose logs -f postgres

# Restart services
docker compose restart synapse
docker compose restart coturn

# Stop/start all services
docker compose down
docker compose up -d

# Recreate a service (after config change)
docker compose up -d --force-recreate synapse
```

## User Management

### Get Admin Token

```bash
# Run on server - get access token for admin API
docker compose exec synapse curl -s -X POST http://localhost:8008/_matrix/client/r0/login \
    -H "Content-Type: application/json" \
    -d '{"type": "m.login.password", "user": "synapse-admin", "password": "PASSWORD"}' \
    | jq -r '.access_token'
```

### Set User Password

```bash
# Replace TOKEN with admin access token, USERNAME with target user
docker compose exec synapse curl -s -X PUT \
    "http://localhost:8008/_synapse/admin/v2/users/@USERNAME:matrix.windreserve.de" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer TOKEN" \
    -d '{"password": "new_password"}'
```

### Create New User

```bash
# Interactive (prompts for password)
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u USERNAME \
    http://localhost:8008

# With password (add -a for admin)
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u USERNAME \
    -p PASSWORD \
    http://localhost:8008

# Create admin user
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u USERNAME \
    -p PASSWORD \
    -a \
    http://localhost:8008
```

### List Users

```bash
# Via database
docker compose exec postgres psql -U synapse -d synapse \
    -c "SELECT name, displayname, admin FROM users ORDER BY name;"

# Via Admin API (requires TOKEN)
docker compose exec synapse curl -s \
    "http://localhost:8008/_synapse/admin/v2/users?limit=100" \
    -H "Authorization: Bearer TOKEN" | jq '.users[] | {name, displayname, admin}'
```

### Deactivate User

```bash
docker compose exec synapse curl -s -X POST \
    "http://localhost:8008/_synapse/admin/v1/deactivate/@USERNAME:matrix.windreserve.de" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer TOKEN" \
    -d '{"erase": false}'
```

### Get User Info

```bash
docker compose exec synapse curl -s \
    "http://localhost:8008/_synapse/admin/v2/users/@USERNAME:matrix.windreserve.de" \
    -H "Authorization: Bearer TOKEN" | jq .
```

## Room Management

### List Rooms

```bash
docker compose exec synapse curl -s \
    "http://localhost:8008/_synapse/admin/v1/rooms?limit=50" \
    -H "Authorization: Bearer TOKEN" | jq '.rooms[] | {room_id, name, num_joined_members}'
```

### Get Room Details

```bash
docker compose exec synapse curl -s \
    "http://localhost:8008/_synapse/admin/v1/rooms/ROOM_ID" \
    -H "Authorization: Bearer TOKEN" | jq .
```

### Delete Room

```bash
docker compose exec synapse curl -s -X DELETE \
    "http://localhost:8008/_synapse/admin/v2/rooms/ROOM_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer TOKEN" \
    -d '{"purge": true}'
```

## Database

```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U synapse -d synapse

# Run SQL query
docker compose exec postgres psql -U synapse -d synapse -c "SELECT COUNT(*) FROM users;"

# Backup database
docker compose exec postgres pg_dump -U synapse synapse > backup.sql

# Restore database
cat backup.sql | docker compose exec -T postgres psql -U synapse synapse
```

## Health Checks

```bash
# Check Synapse API
curl -s https://matrix.windreserve.de/_matrix/client/versions | jq .

# Check federation
curl -s https://matrix.windreserve.de/.well-known/matrix/server

# Check TURN ports
nc -zv turn.windreserve.de 3478
nc -zu turn.windreserve.de 3478

# Container health
docker compose ps
```

## Logs and Debugging

```bash
# Synapse logs (last 100 lines)
docker compose logs synapse --tail=100

# Follow logs in real-time
docker compose logs -f synapse

# Check for errors
docker compose logs synapse 2>&1 | grep -i error

# Caddy access logs
docker compose logs caddy --tail=100
```

## SSL Certificates

Caddy handles SSL automatically via Let's Encrypt.

```bash
# Check certificate status
docker compose exec caddy caddy list-certificates

# Force certificate renewal
docker compose restart caddy
```

## Media Storage

```bash
# Check media storage usage
docker compose exec synapse du -sh /data/media_store

# List media files
docker compose exec synapse ls -la /data/media_store/local_content/
```

## Configuration

```bash
# Edit Synapse config (on server)
nano /root/windreserve-element/synapse/homeserver.yaml

# Edit coturn config
nano /root/windreserve-element/coturn/turnserver.conf

# Edit Caddy config
nano /root/windreserve-element/caddy/Caddyfile

# After config changes, restart the service
docker compose restart synapse
```
