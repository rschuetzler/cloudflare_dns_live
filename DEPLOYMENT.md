# Deployment Guide - DNS Management Portal

This guide covers how to deploy the DNS Management Portal for educational use.

## Prerequisites

1. **Cloudflare Account**: You need a Cloudflare account with the `is404.net` domain configured
2. **Cloudflare API Token**: Create an API token with:
   - Zone:Read permissions for your zone
   - Zone:DNS:Edit permissions for your zone
3. **Cloudflare Zone ID**: Found in your zone's overview page

## Environment Variables

The application requires these environment variables:

### Required Variables

- `CLOUDFLARE_TOKEN`: Your Cloudflare API token
- `CLOUDFLARE_ZONE`: The Zone ID for is404.net
- `ACCESS_PASSWORD`: Password students use to access the portal
- `SECRET_KEY_BASE`: Phoenix secret key (generate with `mix phx.gen.secret`)

### Optional Variables

- `PORT`: Port to run the application on (default: 4000)
- `MIX_ENV`: Environment (dev/test/prod)

## Local Development

1. **Clone and setup**:
   ```bash
   cd cloudflare_dns
   mix deps.get
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   export $(cat .env | xargs)
   ```

3. **Run the application**:
   ```bash
   mix phx.server
   ```

4. **Access the application**:
   - Open http://localhost:4000/login
   - Enter your ACCESS_PASSWORD to access the dashboard

## Production Deployment

### Option 1: Fly.io (Recommended)

1. **Install flyctl**: https://fly.io/docs/getting-started/installing-flyctl/

2. **Login to Fly.io**:
   ```bash
   flyctl auth login
   ```

3. **Initialize the app**:
   ```bash
   flyctl launch
   ```

4. **Set secrets**:
   ```bash
   flyctl secrets set CLOUDFLARE_TOKEN=your_token_here
   flyctl secrets set CLOUDFLARE_ZONE=your_zone_id_here  
   flyctl secrets set ACCESS_PASSWORD=your_password_here
   flyctl secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   ```

5. **Deploy**:
   ```bash
   flyctl deploy
   ```

### Option 2: Docker

1. **Build the image**:
   ```bash
   docker build -t dns-portal .
   ```

2. **Run the container**:
   ```bash
   docker run -p 4000:4000 \
     -e CLOUDFLARE_TOKEN=your_token \
     -e CLOUDFLARE_ZONE=your_zone_id \
     -e ACCESS_PASSWORD=your_password \
     -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
     dns-portal
   ```

### Option 3: Traditional Server

1. **Build a release**:
   ```bash
   MIX_ENV=prod mix deps.get --only prod
   MIX_ENV=prod mix compile
   MIX_ENV=prod mix assets.deploy
   MIX_ENV=prod mix release
   ```

2. **Run the release**:
   ```bash
   CLOUDFLARE_TOKEN=your_token \
   CLOUDFLARE_ZONE=your_zone_id \
   ACCESS_PASSWORD=your_password \
   SECRET_KEY_BASE=your_secret \
   _build/prod/rel/cloudflare_dns/bin/cloudflare_dns start
   ```

## Security Considerations

1. **Access Password**: Choose a strong password that's easy for students to remember but hard to guess
2. **API Token**: Use the minimum required permissions for your Cloudflare token
3. **HTTPS**: Always use HTTPS in production (Fly.io provides this automatically)
4. **Rate Limiting**: Consider adding rate limiting for production deployments
5. **Firewall**: Restrict access to your server as needed

## Student Usage

Students will:
1. Go to your deployed URL
2. Enter the shared ACCESS_PASSWORD
3. View existing DNS records (paginated and searchable)
4. Create new A and CNAME records for subdomains
5. Edit their own records (marked as "STUDENT")
6. Delete their own records
7. See real-time updates as other students make changes

## Cleanup

To clean up student records, you can:
1. Use the Cloudflare dashboard to filter by comment="STUDENT"  
2. Bulk delete these records before each new class/semester
3. Protected records (comment="KEEP") cannot be modified by students

## Monitoring

- DNS records are cached and refreshed every 2 minutes
- All operations are logged in the Phoenix console
- Failed API calls are logged with error details
- Students see helpful error messages for validation failures

## Support

For issues:
1. Check the Phoenix logs for API errors
2. Verify environment variables are set correctly
3. Confirm Cloudflare API token has required permissions
4. Test API access manually with curl if needed