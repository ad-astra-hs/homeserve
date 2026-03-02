# Homeserve 🏠

A selfhosted webcomic server built with Gleam. Stores panels in Mnesia (Erlang's built-in database) for reliability and serves them with simplicity.

## What it does

Homeserve lets you:
- Serve webcomics from Mnesia with markdown content
- Add images, videos, and audio to your comics
- Keep track of contributors with a Hall of Fame
- Customize any panels with CSS and JavaScript
- Manage panels via an admin web interface
- Manage volunteer/collaborator profiles via the admin interface

## Requirements

- [Gleam](https://gleam.run/) installed
- [Erlang/OTP](https://www.erlang.org/) (for Mnesia database)

## Quick Start

1. Clone this repo and enter the directory

2. Copy and customize the config:
   ```bash
   cp homeserve.example.toml homeserve.toml
   ```

3. Verify database initialization:
   ```bash
   # Verify Mnesia is initialized (with persistent storage)
   ERL_FLAGS="-sname homeserve" gleam run -m setup verify

   # Generate a secure admin token (recommended for production)
   gleam run -m setup token
   ```

4. Start the server with persistent storage:
   ```bash
   # Using just (recommended)
   just run

   # Or manually with ERL_FLAGS
   ERL_FLAGS="-sname homeserve" gleam run
   ```

5. Visit `http://localhost:8000`

### Development Mode

For development, you can run without the node name (data will be stored in memory only):

```bash
just run-dev
# or
gleam run
```

## Data Structures

### Panels

Panels are stored as records in Mnesia with this structure:

```json
{
  "type": "panel",
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

## Admin Panel

Access the admin panel at `/admin?token=YOUR_TOKEN` (set in `homeserve.toml`).

From there you can:
- Create new panels
- Edit existing panels
- Delete panels
- View all panels and their status

### Volunteer Management

Volunteers/collaborators can be managed from `/admin/volunteers?token=YOUR_TOKEN`:
- Create volunteer profiles with name, bio, and social links
- Edit existing volunteer information
- Delete volunteers
- View all volunteers

Volunteer profiles appear on contributor pages (`/hoc/<name>`) when a contributor matches a volunteer name.

## Configuration

See `homeserve.example.toml` for all available options including:
- Server port and host
- Mnesia data directory (optional)
- Admin authentication token
- Contact email (for privacy policy)

## Production Deployment

### Using Caddy (Recommended)

For production, run Homeserve behind a reverse proxy like [Caddy](https://caddyserver.com/):

```bash
# Install Caddy
# See https://caddyserver.com/docs/install

# Use the example Caddyfile
cp Caddyfile.example Caddyfile
# Edit Caddyfile with your domain

# Run Caddy
caddy run --config Caddyfile
```

Caddy handles:
- **HTTPS** (automatic Let's Encrypt certificates)
- **Static assets** (served directly, bypassing the app)
- **Rate limiting** (configured for admin endpoints)
- **Compression** (gzip/brotli)

### Admin Token Security

For production, use a SHA-256 hashed admin token:

```bash
# Generate a secure token
gleam run -m setup token

# Copy the hashed value to homeserve.toml
token = "sha256:..."
```

Users still enter the plaintext token, but the config only stores the hash.

### Mnesia Data Persistence

Mnesia requires an Erlang node name to enable persistent disk storage (`disc_copies`). Without it, data is stored in RAM only (`ram_copies`).

**To enable persistent storage, start with a node name:**

```bash
ERL_FLAGS="-sname homeserve" gleam run
```

Or use `just run` which sets this automatically.

**Custom data directory:**

```toml
[mnesia]
data_dir = "/var/lib/homeserve/mnesia"
```

Make sure the directory exists and is writable by the user running Homeserve.

## Architecture

Built with Gleam → Erlang/BEAM for concurrency and reliability.

- **Mnesia**: Built-in Erlang/BEAM database for storing panels and volunteers
- **SHA-256**: Secure hashing for admin tokens
- **Lustre**: HTML rendering with type-safe CSS

Rate limiting for admin endpoints is handled by Caddy (reverse proxy).

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Detailed deployment guide with Caddy
- **[Caddyfile.example](Caddyfile.example)**: Example reverse proxy configuration with rate limiting

## License

See [LICENSE](LICENSE) file.
