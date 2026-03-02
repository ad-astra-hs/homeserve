# Deployment Guide

Deploy Homeserve with Caddy as a reverse proxy using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- A server with ports 80 and 443 available
- A domain name pointing to your server

## Quick Start

### 1. Create Caddyfile

Copy the example and update your domain:

```bash
cp Caddyfile.example Caddyfile
```

Edit `Caddyfile` and replace `homeserve.example.com` with your domain:

```caddy
yourdomain.com {
    encode gzip zstd

    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Serve static assets directly
    handle_path /assets/* {
        root * /path/to/homeserve/priv/static
        file_server
        header Cache-Control "public, max-age=604800"
    }

    # Rate limit admin endpoints
    handle_path /admin* {
        rate_limit {
            zone admin {
                key {remote_host}
                events 10
                window 1m
            }
        }
        reverse_proxy homeserve:8000
    }

    # Forward everything else to Homeserve
    reverse_proxy homeserve:8000
}
```

### 2. Create homeserve.toml

```bash
cp homeserve.example.toml homeserve.toml
```

Edit `homeserve.toml` with your settings:

```toml
[server]
port = 8000
host = "0.0.0.0"

# Optional: Custom data directory for Mnesia
# [mnesia]
# data_dir = "/var/lib/homeserve/mnesia"

[admin]
# Generate with: gleam run -m setup token
token = "sha256:..."

[contact]
email = "admin@example.com"
```

### 3. Create docker-compose.yml

```yaml
version: '3'

services:
  homeserve:
    build: .
    volumes:
      # Persist Mnesia data
      - mnesia_data:/app/data
      # Mount config
      - ./homeserve.toml:/app/homeserve.toml:ro
      # Mount static assets
      - ./priv/static:/app/priv/static:ro
    environment:
      - MNESIA_DATA_DIR=/app/data

  caddy:
    image: caddy:builder
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
      - ./priv/static:/var/www/static:ro
    depends_on:
      - homeserve
    # Build with rate_limit module
    command: >
      sh -c "xcaddy build --with github.com/mholt/caddy-ratelimit &&
             caddy run --config /etc/caddy/Caddyfile"

volumes:
  mnesia_data:
  caddy_data:
  caddy_config:
```

### 4. Deploy

```bash
# Build and start all services
docker-compose up -d

# Verify everything is running
docker-compose ps

# View logs
docker-compose logs -f
```

## First Setup

Generate a secure admin token:

```bash
# Install dependencies locally
gleam deps download

# Generate token
gleam run -m setup token
```

Copy the hashed token to your `homeserve.toml` and restart:

```bash
docker-compose restart homeserve
```

## Security Checklist

- [ ] Change default admin token
- [ ] Use SHA-256 hashed token in production
- [ ] Keep Caddy HTTPS automatic
- [ ] Ensure Mnesia data directory has proper permissions

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Update to latest version
git pull
docker-compose up -d --build

# Stop everything
docker-compose down

# Backup Mnesia data
docker exec homeserve-homeserve-1 tar czf - /app/data > backup.tar.gz

# Restore Mnesia data
docker exec -i homeserve-homeserve-1 tar xzf - -C /app/data < backup.tar.gz
```

## Mnesia Database

Homeserve uses Mnesia, Erlang/BEAM's built-in distributed database. No external database is required!

### Data Storage

- By default, Mnesia stores data in the Erlang Mnesia directory
- For Docker deployments, a volume is mounted at `/app/data`
- You can specify a custom directory in `homeserve.toml`:

```toml
[mnesia]
data_dir = "/var/lib/homeserve/mnesia"
```

### Understanding Storage Modes

Mnesia operates in two storage modes:

1. **`disc_copies`** (Persistent) - Data survives restarts
   - Enabled when running with Erlang node name: `ERL_FLAGS="-sname homeserve"`
   - Data stored in Mnesia directory (configurable via `data_dir`)
   
2. **`ram_copies`** (In-Memory) - Data lost on restart
   - Used when running without node name: `gleam run`
   - Useful for development and testing

### Backup and Restore

#### Method 1: File System Backup (Recommended)

When using persistent storage (`disc_copies`), Mnesia stores data in regular files:

```bash
# Find your Mnesia data directory
# Default: ./Mnesia.homeserve@hostname/ in project root
# Or: configured data_dir from homeserve.toml

# Backup while running (Mnesia supports hot backups)
tar czf homeserve-backup-$(date +%Y%m%d).tar.gz Mnesia.homeserve@*/

# Restore (stop application first)
# 1. Stop homeserve
# 2. Extract backup
tar xzf homeserve-backup-20240101.tar.gz
# 3. Start homeserve
```

#### Method 2: Docker Volume Backup

```bash
# Backup
docker run --rm -v homeserve_mnesia_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/mnesia-backup.tar.gz -C /data .

# Restore (with homeserve stopped)
docker run --rm -v homeserve_mnesia_data:/data -v $(pwd):/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/mnesia-backup.tar.gz -C /data"
```

#### Method 3: Mnesia Native Backup (Advanced)

For consistent backups during heavy write loads:

```erlang
%% In Erlang shell (gleam shell)
mnesia:backup("/path/to/backup.bup").

%% To restore:
mnesia:restore("/path/to/backup.bup", [{default, recreate_tables}]).
```

### Backup Strategy Recommendations

| Environment | Frequency | Method |
|-------------|-----------|--------|
| Production | Daily + before updates | Docker volume or filesystem backup |
| Staging | Weekly | Filesystem backup |
| Development | As needed | None (use ram_copies) |

### Troubleshooting

**Issue: Data not persisting after restart**
- Check you're running with node name: `ERL_FLAGS="-sname homeserve"`
- Verify data directory permissions
- Check logs for schema creation messages

**Issue: Schema errors when switching node names**
- Mnesia schema is tied to the node name
- When changing from `nonode@nohost` to `homeserve@hostname`, schema is recreated automatically
- Data from `ram_copies` is lost when switching to `disc_copies`

**Issue: Backup restoration fails**
- Ensure homeserve is stopped during restore
- Verify backup file integrity: `tar tzf backup.tar.gz`
- Check ownership/permissions of restored files


