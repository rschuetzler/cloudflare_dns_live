# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Dependencies
```bash
mix deps.get                    # Install dependencies
mix setup                      # Install dependencies and build assets
```

### Development Server
```bash
mix phx.server                 # Start development server at http://localhost:4000
iex -S mix phx.server         # Start server with interactive Elixir shell
```

### Code Quality and Testing
```bash
mix test                       # Run all tests
mix format                     # Format all Elixir code
mix compile --warning-as-errors # Compile with strict warnings
mix precommit                  # Run full precommit check (compile, format, test)
```

### Assets
```bash
mix assets.build              # Build CSS/JS assets
mix assets.deploy             # Build and minify assets for production
```

## Architecture Overview

This is an educational Phoenix LiveView application for DNS management using the Cloudflare API. The architecture follows a layered approach:

### Core Application Layer (`lib/cloudflare_dns/`)
- **Application**: OTP application supervisor managing all processes
- **CloudflareClient**: HTTP client for Cloudflare API operations (list, create, update, delete DNS records)
- **DNSCache**: ETS-based caching GenServer with automatic refresh every 2 minutes and PubSub broadcasting
- **DNSValidator**: Validation logic for DNS records with educational restrictions (only A/CNAME, no www/root/wildcard)
- **Mailer**: Email configuration (currently unused)

### Web Layer (`lib/cloudflare_dns_web/`)
- **Auth**: Session-based authentication using ACCESS_PASSWORD environment variable
- **Router**: Route definitions with auth protection on all routes except `/login`
- **LiveViews**:
  - `DashboardLive`: Main interface with search, pagination, and real-time updates
  - `RecordLive`: DNS record creation/editing forms
  - `LoginLive`: Password authentication
- **Components**: Core UI components and layouts using Tailwind CSS

### Key Design Patterns

**Real-time Updates**: Uses Phoenix PubSub to broadcast DNS changes to all connected clients. The DNSCache publishes updates on the `"dns_records"` topic.

**ETS Caching**: DNS records are cached in ETS tables for fast access, automatically refreshed every 2 minutes, and manually invalidated after record operations.

**Educational Safety**: DNSValidator restricts operations to prevent dangerous changes:
- Only A and CNAME records allowed
- Cannot create www, @, or wildcard records  
- Protected records (comment: "KEEP") cannot be modified
- Student records (comment: "STUDENT") can be edited/deleted

**Pagination and Search**: DashboardLive implements client-side pagination (20 records per page) and search across name/content/type fields.

## Environment Configuration

Required environment variables:
- `CLOUDFLARE_TOKEN`: API token with Zone:Read and Zone:DNS:Edit permissions
- `CLOUDFLARE_ZONE`: Zone ID for the target domain (hardcoded to is404.net)
- `ACCESS_PASSWORD`: Password for student authentication
- `SECRET_KEY_BASE`: Phoenix secret key (generate with `mix phx.gen.secret`)

Optional:
- `PORT`: Server port (defaults to 4000)
- `MIX_ENV`: Environment (dev/test/prod)

## Development Notes

### Phoenix LiveView Components
- Uses function components (`~H` sigil) and HEEx templates
- Real-time updates via PubSub subscriptions in `mount/3`
- URL-based search/pagination using `handle_params/3`

### Testing Strategy
- Tests are located in `test/` directory
- Run individual test files: `mix test test/path/to/file_test.exs`
- Use `ExUnit` for unit tests

### Code Structure Conventions
- Modules follow `CloudflareDns.*` and `CloudflareDnsWeb.*` naming
- LiveViews use `mount/3`, `handle_params/3`, `handle_event/3`, and `handle_info/3`
- GenServer callbacks follow OTP patterns with proper state management
- Validation functions return `{:ok, data}` or `{:error, errors}` tuples

### Security Considerations
- All routes except `/login` require authentication
- Input validation prevents malicious DNS records
- API tokens and passwords are loaded from environment variables
- Protected DNS records cannot be modified by students