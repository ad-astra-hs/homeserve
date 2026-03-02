# Deployment Guide

Complete guide for deploying Homeserve in production using Docker Compose with Caddy as a reverse proxy.

## 📋 Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- A server with ports 80 and 443 available
- A domain name with DNS pointing to your server
- Basic familiarity with command line and Docker

## 🚀 Quick Start

### 1. Configure Caddy

Copy the example and customize for your domain:

```bash
cp Caddyfile.example Caddyfile
```

Edit `Caddyfile` with your domain and paths:

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

    # Serve static assets directly (bypasses the app)
    handle_path /assets/* {
        root * /path/to/homeserve/priv/static
        file_server
        header Cache-Control "public, max-age=604800"
    }

    # Forward everything to Homeserve
    reverse_proxy homeserve:8000
}
```

**Important:** Replace:
- `yourdomain.com` with your actual domain
- `/path/to/homeserve/priv/static` with the absolute path to your static files

### 2. Configure Homeserve

```bash
cp homeserve.example.toml homeserve.toml
```

Edit `homeserve.toml`:

```toml
[server]
port = 8000
host = "0.0.0.0"

[mnesia]
data_dir = "/app/data"

[admin]
# Generate with: gleam run -m setup token
token = "sha256:salt:hash"

[contact]
email = "admin@yourdomain.com"

[logging]
level = "info"
```

### 3. Create docker-compose.yml

```yaml
version: '3.8'

services:
  homeserve:
    build: .
    container_name: homeserve-app
    volumes:
      # Persist Mnesia database
      - mnesia_data:/app/data
      # Mount configuration (read-only)
      - ./homeserve.toml:/app/homeserve.toml:ro
      # Mount static assets (read-only)
      - ./priv/static:/app/priv/static:ro
    environment:
      - MNESIA_DATA_DIR=/app/data
    restart: unless-stopped
    networks:
      - homeserve-network

  caddy:
    image: caddy:latest
    container_name: homeserve-caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
      - ./priv/static:/var/www/static:ro
    depends_on:
      - homeserve
    restart: unless-stopped
    networks:
      - homeserve-network

volumes:
  mnesia_data:
  caddy_data:
  caddy_config:

networks:
  homeserve-network:
    driver: bridge
```

### 4. Deploy

```bash
# Build and start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Verify services are running
curl http://localhost
```

## 🔐 First Setup

### Generate Admin Token

Before accessing the admin panel, generate a secure token:

```bash
# Install dependencies locally
gleam deps download

# Generate a secure hashed token
gleam run -m setup token
```

You'll see output like:

```
Plaintext: my-secret-token-123
Hashed: sha256:a1b2c3d4:hash-here

Copy the hashed value to homeserve.toml:
token = "sha256:a1b2c3d4:hash-here"
```

Update your `homeserve.toml` with the hashed token and restart:

```bash
docker-compose restart homeserve
```

Access the admin panel at: `https://yourdomain.com/admin?token=my-secret-token-123`

## ✅ Security Checklist

Before going live, ensure:

- [ ] **Admin token changed** - Not using default "changeme"
- [ ] **Token hashed** - Using SHA-256 format for production
- [ ] **HTTPS enabled** - Caddy automatically handles this
- [ ] **Data directory secured** - Proper permissions on Mnesia data
- [ ] **Static assets served by Caddy** - Configured in Caddyfile
- [ ] **Contact email set** - For privacy policy page
- [ ] **Logging configured** - Set to appropriate level (info for production)

## 🔧 Operational Commands

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f homeserve
docker-compose logs -f caddy

# Last 100 lines
docker-compose logs --tail=100 homeserve
```

### Restarting Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart homeserve
docker-compose restart caddy

# Recreate and restart
docker-compose up -d --force-recreate
```

### Updating Homeserve

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose up -d --build

# Verify update
docker-compose logs homeserve
```

### Stopping Services

```bash
# Stop but keep data
docker-compose down

# Stop and remove volumes (WARNING: data loss)
docker-compose down -v
```

## 💾 Database Backup and Restore

### Automatic Backups (Recommended)

Create a backup script at `/usr/local/bin/backup-homeserve.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/homeserve"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup Mnesia data
docker exec homeserve-app tar czf - /app/data > "$BACKUP_DIR/homeserve_$DATE.tar.gz"

# Keep only last 7 backups
ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup completed: homeserve_$DATE.tar.gz"
```

Make it executable and add to crontab:

```bash
chmod +x /usr/local/bin/backup-homeserve.sh

# Add to crontab (daily at 2 AM)
echo "0 2 * * * /usr/local/bin/backup-homeserve.sh" | crontab -
```

### Manual Backup

```bash
# Create backup
docker exec homeserve-app tar czf - /app/data > homeserve-backup-$(date +%Y%m%d).tar.gz

# Verify backup
tar tzf homeserve-backup-*.tar.gz
```

### Manual Restore

⚠️ **Warning:** This will overwrite existing data. Stop Homeserve first.

```bash
# Stop homeserve
docker-compose stop homeserve

# Restore from backup
docker exec -i homeserve-app tar xzf - -C /app/data < homeserve-backup-20240101.tar.gz

# Restart
docker-compose start homeserve
```

### Backup Strategy

| Environment | Frequency | Retention | Method |
|-------------|-----------|-----------|--------|
| Production | Daily | 7 days | Automated script |
| Production | Before updates | Permanent | Manual snapshot |
| Staging | Weekly | 4 weeks | Manual |
| Development | As needed | None | None |

## 🗄️ Mnesia Database

Homeserve uses [Mnesia](https://www.erlang.org/doc/apps/mnesia/mnesia.html), Erlang/BEAM's built-in distributed database. No external database server is required!

### Storage Modes

Mnesia operates in two storage modes:

| Mode | Persistence | Use Case | Activation |
|------|-------------|----------|------------|
| `disc_copies` | Data survives restarts | Production | `ERL_FLAGS="-sname homeserve"` |
| `ram_copies` | Data lost on restart | Development | Run without node name |

### Data Location

- **Docker**: `/app/data` (volume `mnesia_data`)
- **Host**: Default Erlang Mnesia directory
- **Custom**: Configurable via `homeserve.toml`

### Database Schema

The database consists of two tables:

1. **panel** - Stores comic panels (key: integer index)
2. **volunteer** - Stores volunteer profiles (key: string name)

## 🐛 Troubleshooting

### Data Not Persisting

**Symptoms:** Data lost after container restart

**Solutions:**
1. Ensure you're using persistent storage mode
2. Check the volume is mounted correctly:
   ```bash
   docker volume inspect homeserve_mnesia_data
   ```
3. Verify `data_dir` in homeserve.toml matches the volume mount

### SSL Certificate Issues

**Symptoms:** HTTPS not working or certificate errors

**Solutions:**
1. Ensure ports 80 and 443 are open
2. Check DNS is pointing to the correct IP
3. Verify Caddy can reach Let's Encrypt:
   ```bash
   docker-compose logs caddy
   ```

### Cannot Access Admin Panel

**Symptoms:** 401 Unauthorized errors

**Solutions:**
1. Verify token in URL matches the plaintext version
2. Check token format in homeserve.toml:
   - Plaintext: `token = "my-secret"`
   - Hashed: `token = "sha256:salt:hash"`
3. Ensure token is properly quoted

### Database Schema Errors

**Symptoms:** Mnesia errors in logs

**Solutions:**
1. Schema is tied to node name - changing it recreates the schema
2. If switching between `ram_copies` and `disc_copies`, data is lost
3. To reset the database:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

### High Memory Usage

**Symptoms:** Container using too much RAM

**Solutions:**
1. Mnesia loads entire tables into memory - this is normal
2. For large datasets, consider implementing pagination
3. Monitor memory usage:
   ```bash
   docker stats homeserve-app
   ```

## 📝 Configuration Reference

### Homeserve Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MNESIA_DATA_DIR` | Mnesia data directory | `./data` |
| `ERL_FLAGS` | Erlang runtime flags | `-sname homeserve` |

### Docker Compose Options

```yaml
# Resource limits (add to homeserve service)
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '1.0'
    reservations:
      memory: 256M
      cpus: '0.5'
```

### Caddy Advanced Options

```caddy
# Enable access logging
log {
    output file /var/log/caddy/access.log
    format json
}

# Custom error pages
handle_errors {
    rewrite * /error.html
    file_server
}
```

## 📊 Monitoring

### Health Checks

Add to `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### Log Rotation

Add to `docker-compose.yml` for Caddy:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 🔗 External Resources

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Mnesia User Guide](https://www.erlang.org/doc/apps/mnesia/mnesia.html)
- [Homeserve README](README.md)
