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

[couchdb]
host = "couchdb"
port = 5984
database = "homeserve_panels"
username = "admin"
password = "your-secure-password"

[admin]
# Generate with: gleam run -m setup token
token = "$2b$10$..."

[contact]
email = "admin@example.com"
```

### 3. Create docker-compose.yml

```yaml
version: '3'

services:
  couchdb:
    image: couchdb:latest
    environment:
      COUCHDB_USER: admin
      COUCHDB_PASSWORD: ${COUCHDB_PASSWORD}
    volumes:
      - couchdb_data:/opt/couchdb/data

  homeserve:
    build: .
    environment:
      COUCHDB_HOST: couchdb
      COUCHDB_PASSWORD: ${COUCHDB_PASSWORD}
    depends_on:
      - couchdb

  caddy:
    image: caddy:builder
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - homeserve
    # Build with rate_limit module
    command: >
      sh -c "xcaddy build --with github.com/mholt/caddy-ratelimit &&
             caddy run --config /etc/caddy/Caddyfile"

volumes:
  couchdb_data:
  caddy_data:
  caddy_config:
```

### 4. Configure Environment

Create a `.env` file:

```bash
COUCHDB_PASSWORD=your-secure-password
```

### 5. Deploy

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
- [ ] Set strong CouchDB password
- [ ] Use bcrypt hashed token in production
- [ ] Keep Caddy HTTPS automatic

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

# Backup CouchDB
docker exec homeserve-couchdb-1 tar czf - /opt/couchdb/data > backup.tar.gz
```
