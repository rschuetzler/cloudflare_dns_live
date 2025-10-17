# Docker Deployment Guide

This guide explains how to build and deploy the Cloudflare DNS application using Docker.

## Prerequisites

- Docker installed on your system
- Docker Compose (optional, but recommended)
- Environment variables configured (see `.env.example`)

## Building the Docker Image

The Dockerfile uses the official Elixir 1.18 image from [erlef/docker-elixir](https://github.com/erlef/docker-elixir) and creates a multi-stage build for optimal image size.

### Build the image:

```bash
docker build -t cloudflare-dns:latest .
```

### Build with specific Elixir version:

```bash
docker build --build-arg ELIXIR_VERSION=1.18 -t cloudflare-dns:latest .
```

## Running with Docker

### Using docker run:

```bash
docker run -d \
  -p 4000:4000 \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e CLOUDFLARE_TOKEN="your_token" \
  -e CLOUDFLARE_ZONE="your_zone_id" \
  -e CLOUDFLARE_DOMAIN="your-domain.com" \
  -e ACCESS_PASSWORD="your_password" \
  -e PHX_HOST="your-host.com" \
  --name cloudflare-dns \
  cloudflare-dns:latest
```

### Using Docker Compose (Recommended):

1. Copy the example environment file and configure it:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. Generate a secret key base:
   ```bash
   # Run this outside the container
   mix phx.gen.secret
   # Add the output to your .env file as SECRET_KEY_BASE
   ```

3. Start the application:
   ```bash
   docker-compose up -d
   ```

4. View logs:
   ```bash
   docker-compose logs -f
   ```

5. Stop the application:
   ```bash
   docker-compose down
   ```

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Phoenix secret key (generate with `mix phx.gen.secret`) | `VGhpc2lzYXNlY3JldGtleQ==` |
| `CLOUDFLARE_TOKEN` | Cloudflare API token with Zone:Read and DNS:Edit permissions | `abc123...` |
| `CLOUDFLARE_ZONE` | Cloudflare Zone ID | `def456...` |
| `CLOUDFLARE_DOMAIN` | Your domain name | `example.com` |
| `ACCESS_PASSWORD` | Password for student authentication | `secure_password` |
| `PHX_HOST` | Public hostname for the application | `dns.example.com` |
| `PORT` | Port to listen on (default: 4000) | `4000` |

## Dockerfile Architecture

The Dockerfile uses a two-stage build:

1. **Builder Stage** (based on `elixir:1.18`):
   - Installs build dependencies
   - Compiles Elixir dependencies
   - Builds frontend assets (Tailwind CSS, esbuild)
   - Creates a production release

2. **Runtime Stage** (based on `debian:bookworm-slim`):
   - Minimal runtime environment
   - Only includes the compiled release
   - Runs as non-root user (`nobody`)
   - Exposes port 4000

## Optimizations

- Multi-stage build reduces final image size
- `.dockerignore` excludes unnecessary files from build context
- Assets are pre-compiled and digested
- Release includes only runtime dependencies
- ERTS (Erlang Runtime System) is bundled in the release

## Health Checks

The Docker Compose configuration includes a health check that verifies the application is responding on port 4000.

## Production Deployment

For production deployments:

1. Set `PHX_HOST` to your actual domain
2. Use a reverse proxy (nginx, Caddy) for SSL/TLS termination
3. Consider using secrets management for sensitive environment variables
4. Set up proper logging and monitoring
5. Use Docker volumes if you need persistent storage
6. Configure resource limits in Docker Compose or Kubernetes

## Troubleshooting

### Container exits immediately
- Check logs: `docker-compose logs`
- Verify all required environment variables are set
- Ensure SECRET_KEY_BASE is properly generated

### Cannot connect to Cloudflare API
- Verify CLOUDFLARE_TOKEN has correct permissions
- Check CLOUDFLARE_ZONE ID is correct
- Ensure container has network access

### Port already in use
- Change the PORT environment variable
- Update the port mapping in docker-compose.yml

## Building for Different Platforms

To build for a specific platform (e.g., ARM64 for Apple Silicon):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t cloudflare-dns:latest .
```
