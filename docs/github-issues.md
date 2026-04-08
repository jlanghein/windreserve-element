# GitHub Issues for Migration

Create these issues in https://github.com/jlanghein/windreserve-element/issues

---

## Issue 1: Provision Hetzner Cloud VM

**Labels**: `infrastructure`, `priority: high`

### Task
Provision a new Hetzner Cloud VM for the Matrix/Element setup.

### Specs
- **Type**: CX21 (2 vCPU, 4GB RAM, 40GB SSD) - €4.85/month
- **OS**: Debian 12
- **Location**: Nuremberg (nbg1) or Falkenstein (fsn1)

### Steps
- [ ] Create VM in Hetzner Cloud Console
- [ ] Note the public IP address
- [ ] Set up SSH access
- [ ] Update firewall rules (80, 443, 3478, 5349, 49152-49200/udp)
- [ ] Install Docker and docker-compose

### Commands
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin

# Verify
docker --version
docker compose version
```

---

## Issue 2: Create DNS records

**Labels**: `infrastructure`, `priority: high`

### Task
Create DNS A records in Strato for the new setup.

### Records to create
| Record | Type | Value |
|--------|------|-------|
| `matrix-new.windreserve.de` | A | `<new VM IP>` |
| `element-new.windreserve.de` | A | `<new VM IP>` |
| `turn.windreserve.de` | A | `<new VM IP>` |

### Steps
- [ ] Log into Strato DNS management
- [ ] Create A record for matrix-new
- [ ] Create A record for element-new
- [ ] Create/update A record for turn
- [ ] Wait for DNS propagation (check with `dig`)

---

## Issue 3: Deploy Docker Compose stack

**Labels**: `deployment`, `priority: high`

### Task
Deploy the initial Docker Compose stack on the new VM.

### Steps
- [ ] Clone this repo to the VM
- [ ] Copy `.env.example` to `.env`
- [ ] Generate secure passwords and update `.env`
- [ ] Download Element web files
- [ ] Start services with `docker compose up -d`
- [ ] Verify all containers are running

### Commands
```bash
# Clone repo
git clone git@github.com:jlanghein/windreserve-element.git
cd windreserve-element

# Setup env
cp .env.example .env
# Edit .env with secure passwords

# Download Element Web
./scripts/download-element.sh

# Start
docker compose up -d
docker compose ps
```

---

## Issue 4: Export data from old Synapse

**Labels**: `migration`, `priority: high`

### Task
Export all data from the old Synapse server (10.25.10.64).

### Data to export
- [ ] PostgreSQL database (~103 MB)
- [ ] Signing key (CRITICAL)
- [ ] Media files (~1.1 GB)

### Commands
```bash
# On old server (10.25.10.64)
sudo -u postgres pg_dump synapse > /tmp/synapse_backup.sql
sudo cp /etc/matrix-synapse/homeserver.signing.key /tmp/
sudo tar -czf /tmp/synapse_media.tar.gz -C /var/lib/matrix-synapse media/
sudo chmod 644 /tmp/synapse_backup.sql /tmp/homeserver.signing.key /tmp/synapse_media.tar.gz
```

---

## Issue 5: Import data to new Synapse

**Labels**: `migration`, `priority: high`
**Depends on**: #3, #4

### Task
Import the exported data into the new Synapse instance.

### Steps
- [ ] Transfer files from old server to new server
- [ ] Import PostgreSQL database
- [ ] Copy signing key to correct location
- [ ] Extract media files
- [ ] Restart Synapse

### Commands
```bash
# Transfer files
scp windadmin@10.25.10.64:/tmp/synapse_backup.sql ./
scp windadmin@10.25.10.64:/tmp/homeserver.signing.key ./
scp windadmin@10.25.10.64:/tmp/synapse_media.tar.gz ./

# Import database
docker compose up -d postgres
cat synapse_backup.sql | docker compose exec -T postgres psql -U synapse synapse

# Import signing key and media
# (see docs/migration.md for details)

# Restart
docker compose restart synapse
```

---

## Issue 6: Create local user accounts

**Labels**: `migration`, `priority: medium`
**Depends on**: #5

### Task
Create local user accounts for all 35 users (replacing LDAP auth).

### Options
1. **Bulk create** from exported user list
2. **Self-service** - enable registration temporarily
3. **On-demand** - create accounts as users request

### Commands
```bash
# Create a single user
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u USERNAME \
    -p PASSWORD \
    -a  # -a for admin

# Create admin user first
docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u windadmin \
    -a
```

---

## Issue 7: Test and validate

**Labels**: `testing`, `priority: high`
**Depends on**: #5, #6

### Task
Verify the migration was successful.

### Test checklist
- [ ] Element web loads at element-new.windreserve.de
- [ ] Can log in with migrated credentials
- [ ] Old rooms are visible
- [ ] Old messages are visible
- [ ] Can send new messages
- [ ] Voice/video calls work (TURN)
- [ ] File uploads work
- [ ] Federation status check

### Commands
```bash
# Check API
curl https://matrix-new.windreserve.de/_matrix/client/versions

# Check federation
curl https://matrix-new.windreserve.de/.well-known/matrix/server

# Federation tester
# https://federationtester.matrix.org/#matrix-new.windreserve.de
```

---

## Issue 8: DNS cutover to production

**Labels**: `deployment`, `priority: high`
**Depends on**: #7

### Task
After successful testing, switch DNS to point to new server.

### Steps
- [ ] Update `matrix.windreserve.de` A record → new VM IP
- [ ] Update `element.windreserve.de` A record → new VM IP
- [ ] Update homeserver.yaml with final domain names
- [ ] Update element config.json with final domain names
- [ ] Restart all services
- [ ] Verify everything works
- [ ] Update HAProxy on opn.nue (remove old backends)

---

## Issue 9: Decommission old infrastructure

**Labels**: `cleanup`, `priority: low`
**Depends on**: #8

### Task
After 1 week of stable operation, clean up old infrastructure.

### Steps
- [ ] Wait 1 week after cutover
- [ ] Verify no issues reported
- [ ] Stop old Synapse VM (306) on oxygen
- [ ] Stop old Element-web VM (310) on oxygen
- [ ] Remove Caddy routes on oxygen
- [ ] Archive VMs (or delete after backup)
- [ ] Update documentation
