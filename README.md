# Homeserve 🏠

A selfhosted webcomic server built with Gleam. Stores panels in CouchDB for reliability and serves them with simplicity.

## What it does

Homeserve lets you:
- Serve webcomics from CouchDB with markdown content
- Add images, videos, and audio to your comics
- Keep track of contributors with a Hall of Fame
- Customize any panels with CSS and JavaScript
- Manage panels via an admin web interface
- Manage volunteer/collaborator profiles via the admin interface

## Requirements

- [Gleam](https://gleam.run/) installed
- [CouchDB](https://couchdb.apache.org/) running (see setup below)

## Quick Start

1. Start CouchDB (using Docker):
   ```bash
   docker run -d -p 5984:5984 \
     -e COUCHDB_USER=admin \
     -e COUCHDB_PASSWORD=password \
     couchdb:latest
   ```

2. Clone this repo and enter the directory

3. Copy and customize the config:
   ```bash
   cp homeserve.example.toml homeserve.toml
   ```

4. Verify database connection and generate a secure admin token:
   ```bash
   # Verify CouchDB is accessible
   gleam run -m setup verify

   # Generate a secure admin token (recommended for production)
   gleam run -m setup token
   ```

5. Start the server:
   ```bash
   gleam run
   ```

6. Visit `http://localhost:8000`

## Data Structures

### Panels

Panels are stored as JSON documents in CouchDB with this structure:

```json
{
  "_id": "panel:1",
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
- CouchDB connection settings
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

For production, use a bcrypt-hashed admin token:

```bash
# Generate a secure token
gleam run -m setup token

# Copy the hashed value to homeserve.toml
token = "$2b$10$..."
```

Users still enter the plaintext token, but the config only stores the hash.

## Architecture

Built with Gleam → Erlang/BEAM for concurrency and reliability.

- **CouchDB**: Stores panel and volunteer documents
- **Bcrypt**: Secure password hashing for admin tokens
- **Lustre**: HTML rendering with type-safe CSS

Rate limiting for admin endpoints is handled by Caddy (reverse proxy).

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Detailed deployment guide with Caddy
- **[Caddyfile.example](Caddyfile.example)**: Example reverse proxy configuration with rate limiting

## License

See [LICENSE](LICENSE) file.
