# Homeserve 🏠

A self-hosted webcomic server built with [Gleam](https://gleam.run/). Stores panels and volunteer data in Mnesia (Erlang's built-in database) for reliability and serves them with simplicity.

## ✨ Features

- **Webcomic hosting** - Serve comics with markdown content
- **Rich media support** - Add images, videos, and audio to panels
- **Hall of Fame** - Track contributors and volunteers
- **Custom styling** - Per-panel CSS and JavaScript support
- **Admin interface** - Web-based management for panels and volunteers
- **Type-safe** - Built with Gleam's type system for reliability

## 📋 Requirements

- [Gleam](https://gleam.run/) (latest version)
- [Erlang/OTP](https://www.erlang.org/) (for Mnesia database and runtime)

## 🚀 Quick Start

### 1. Get the code

```bash
git clone <repo-url>
cd homeserve
```

### 2. Configure

```bash
cp homeserve.example.toml homeserve.toml
# Edit homeserve.toml with your settings
```

### 3. Initialize database

```bash
# Verify Mnesia is ready (persistent storage mode)
ERL_FLAGS="-sname homeserve" gleam run -m setup verify

# Generate a secure admin token for production
gleam run -m setup token
```

### 4. Run the server

**Production mode** (data persists between restarts):

```bash
# Using just (recommended)
just run

# Or manually
ERL_FLAGS="-sname homeserve" gleam run
```

**Development mode** (data in memory only, lost on restart):

```bash
just run-dev
# or
gleam run
```

Visit `http://localhost:8000` to see your comic!

## 📊 Data Structure

### Panels

Panels are stored in Mnesia with this structure:

```json
{
  "meta": {
    "index": 1,
    "title": "My Awesome Comic",
    "media": {
      "kind": "image",
      "url": "/assets/panel1.jpg",
      "alt": "First panel!",
      "track": null
    },
    "credits": {
      "artists": ["Artist Name"],
      "writers": ["Writer Name"],
      "musicians": [],
      "misc": []
    },
    "css": [],
    "js": [],
    "date": 1704067200,
    "draft": false
  },
  "content": "Your name is..."
}
```

## 🎛️ Admin Panel

Access at: `/admin?token=YOUR_TOKEN`

**Panel management:**
- Create, edit, and delete panels
- View all panels and their draft status

**Volunteer management** at `/admin/volunteers?token=YOUR_TOKEN`:
- Create volunteer profiles (name, bio, social links)
- Edit and delete volunteers
- View all volunteers

Volunteer profiles appear on `/hoc/<name>` pages when names match.

## ⚙️ Configuration

Key options in `homeserve.toml`:

| Section | Key | Description | Default |
|---------|-----|-------------|---------|
| `[server]` | `port` | HTTP port | 8000 |
| `[server]` | `host` | Bind address | 0.0.0.0 |
| `[mnesia]` | `data_dir` | Database location | Mnesia default |
| `[admin]` | `token` | Admin auth token | changeme |
| `[contact]` | `email` | Contact address | admin@example.com |
| `[logging]` | `level` | Log level | info |

See `homeserve.example.toml` for all options.

## 🌐 Production Deployment

### Using Caddy (Recommended)

Caddy provides HTTPS, static file serving, and security headers:

```bash
# Install Caddy (https://caddyserver.com/docs/install)

# Setup configuration
cp Caddyfile.example Caddyfile
# Edit Caddyfile with your domain

# Start Caddy
caddy run --config Caddyfile
```

**What Caddy handles:**
- Automatic HTTPS (Let's Encrypt certificates)
- Static asset serving (bypasses the app)
- Compression (gzip/brotli)
- Security headers

### Admin Token Security

For production, generate a SHA-256 hashed token:

```bash
gleam run -m setup token
# Copy output to homeserve.toml:
# token = "sha256:salt:hash"
```

Users enter the plaintext token; only the hash is stored.

### Data Persistence

Mnesia requires an Erlang node name for persistent disk storage:

```bash
# Use this for production (data survives restarts)
ERL_FLAGS="-sname homeserve" gleam run
```

Without the node name, data is stored in RAM only (development mode).

**Custom data directory:**

```toml
[mnesia]
data_dir = "/var/lib/homeserve/mnesia"
```

Ensure the directory exists and is writable.

## 🏗️ Architecture

Homeserve is built with modern, type-safe technologies:

| Component | Technology |
|-----------|------------|
| Language | Gleam (compiles to Erlang/BEAM) |
| Database | Mnesia (built into Erlang) |
| Web Framework | Wisp |
| HTML/CSS | Lustre + Sketch |
| Markdown | Mork |
| Auth | SHA-256 token hashing |
| Rate Limiting | Application-layer (in-memory) |

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed deployment guide with Docker
- **[Caddyfile.example](Caddyfile.example)** - Example reverse proxy configuration
- **[AGENTS.md](AGENTS.md)** - Development guide for contributors

## 📄 License

See [LICENSE](LICENSE) file.
