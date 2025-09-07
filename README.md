# DNS Management Portal

A Phoenix LiveView application for educational DNS management using the Cloudflare API. This portal allows students to learn about DNS by creating, editing, and deleting A and CNAME records in a controlled environment.

## 🎯 Features

- **Password-protected access** using environment variables
- **Real-time updates** with Phoenix LiveView and PubSub
- **Educational guidance** with explanations of DNS record types
- **Student-friendly restrictions** to prevent dangerous operations
- **Searchable and paginated** DNS record listing
- **ETS-based caching** for fast performance
- **Input validation** with helpful error messages
- **Mobile-responsive design** with Tailwind CSS

## 🚀 Quick Start

### Prerequisites
- Elixir 1.15+ and Erlang/OTP 25+
- A Cloudflare account with the target domain
- Cloudflare API token with Zone:Read and Zone:DNS:Edit permissions

### Setup

1. **Clone and install dependencies**:
   ```bash
   cd cloudflare_dns
   mix deps.get
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your Cloudflare credentials and access password
   export $(cat .env | xargs)
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Access the application**:
   - Open [http://localhost:4000/login](http://localhost:4000/login)
   - Enter your `ACCESS_PASSWORD` to access the dashboard

## 🔧 Configuration

Required environment variables:

- `CLOUDFLARE_TOKEN` - Your Cloudflare API token
- `CLOUDFLARE_ZONE` - Zone ID for your domain (e.g., is404.net)  
- `ACCESS_PASSWORD` - Password for student access
- `SECRET_KEY_BASE` - Phoenix secret key (generate with `mix phx.gen.secret`)

## 🎓 Student Usage

Students can:
- ✅ View all DNS records (paginated, searchable)
- ✅ Create A records (subdomain → IP address)
- ✅ Create CNAME records (subdomain → domain alias)
- ✅ Edit their own records (marked as "STUDENT")
- ✅ Delete their own records
- ✅ See real-time updates from other students
- ❌ Cannot create www, root (@), or wildcard (*) records
- ❌ Cannot modify protected records (marked as "KEEP")

## 🏗️ Architecture

- **Phoenix LiveView** - Real-time UI updates
- **ETS Cache** - Fast DNS record caching with 2-minute refresh
- **PubSub Broadcasting** - Live updates to all connected users
- **Cloudflare API Client** - RESTful DNS record management
- **DNS Validator** - Input validation and security controls
- **Password Authentication** - Simple session-based auth

## 📦 Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions including:
- Fly.io deployment (recommended)
- Docker deployment
- Traditional server deployment
- Security considerations

## 🧪 Development

Run tests:
```bash
mix test
```

Format code:
```bash
mix format
```

Start interactive session:
```bash
iex -S mix phx.server
```

## 🛡️ Security Features

- All routes protected except login page
- Input validation prevents malicious DNS records
- Protected records cannot be modified by students
- Robots.txt disallows all crawling
- Minimum required Cloudflare API permissions
- Session-based authentication

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `mix format` and `mix test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For deployment help, see [DEPLOYMENT.md](DEPLOYMENT.md). For issues:

1. Check Phoenix logs for API errors
2. Verify environment variables are correctly set
3. Confirm Cloudflare API token permissions
4. Test API connectivity manually if needed
