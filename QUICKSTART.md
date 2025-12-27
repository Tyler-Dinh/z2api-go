# Quick Start Guide: Tailscale + z2api-go

Get up and running with Tailscale in 5 minutes.

## Prerequisites

- Docker and Docker Compose installed
- A Tailscale account (free tier works great!)

## Step-by-Step Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Tylerx404/z2api-go.git
cd z2api-go
```

### 2. Generate Tailscale Auth Key

1. Visit: https://login.tailscale.com/admin/settings/keys
2. Click **"Generate auth key"**
3. Configure:
   - ✅ Check **"Ephemeral"** (recommended for containers)
   - ✅ Check **"Reusable"** (optional, useful for testing)
   - Set expiration: 90 days
4. Copy the key (starts with `tskey-auth-`)

### 3. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and add your Tailscale auth key
nano .env  # or use your preferred editor
```

Add your key:
```env
TS_AUTH_KEY=tskey-auth-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 4. Start the Services

```bash
docker-compose up -d
```

### 5. Verify Connection

```bash
# Check Tailscale logs
docker logs z2api-go-tailscale

# You should see: "✓ Tailscale connected successfully!"
```

### 6. Test the API

From any device on your Tailscale network:

```bash
# Health check
curl http://z2api-go:8080/health

# List available models
curl http://z2api-go:8080/v1/models

# Test chat completion
curl http://z2api-go:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.7",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Success! 🎉

Your z2api-go service is now:
- ✅ Running on your private Tailscale network
- ✅ Accessible from any of your Tailscale devices
- ✅ Using ephemeral authentication (auto-cleanup)
- ✅ Encrypted with WireGuard

## Next Steps

### Customize Hostname

Want a custom name instead of `z2api-go`?

```env
TS_HOSTNAME=my-custom-api
```

Access via: `http://my-custom-api:8080`

### Add Tags for ACL

Control access with Tailscale ACLs:

```env
TS_EXTRA_ARGS=--advertise-tags=tag:service,tag:production
```

### Access from Mobile

1. Install Tailscale on your phone
2. Connect to your tailnet
3. Access the API: `http://z2api-go:8080`

### Local Development

Want to develop locally without Tailscale?

```bash
docker-compose -f docker-compose.local.yml up -d
```

Access via: `http://localhost:8080`

## Troubleshooting

### "TS_AUTH_KEY is required" Error

Make sure your `.env` file contains:
```env
TS_AUTH_KEY=tskey-auth-...
```

### Can't Connect to API

1. Verify Tailscale is running:
   ```bash
   docker ps | grep tailscale
   ```

2. Check Tailscale status:
   ```bash
   docker exec z2api-go-tailscale tailscale status
   ```

3. Make sure you're connected to Tailscale on your client device

### Need Help?

- See [TAILSCALE.md](TAILSCALE.md) for detailed documentation
- See [README.md](README.md) for general information
- Check [Tailscale Documentation](https://tailscale.com/kb/)

## What's Happening?

```
Your Device (on Tailscale)
         ↓
    [Tailscale Network]
         ↓
   z2api-go Container
   (via Tailscale sidecar)
         ↓
      Z.ai API
```

- **Tailscale sidecar**: Manages VPN connection
- **z2api-go**: Shares Tailscale's network, visible on your tailnet
- **Ephemeral key**: Node auto-removes when stopped (clean!)

## Common Commands

```bash
# View logs
docker logs z2api-go-tailscale
docker logs z2api-go

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Rebuild after changes
docker-compose up -d --build

# Check Tailscale connection
docker exec z2api-go-tailscale tailscale status

# Check Tailscale IP
docker exec z2api-go-tailscale tailscale ip
```

---

**Happy coding!** 🚀

For more details, see [TAILSCALE.md](TAILSCALE.md)
