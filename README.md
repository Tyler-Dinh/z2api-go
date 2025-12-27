# Z2api Go

Proxy API for Z.ai compatible with OpenAI and Anthropic, written in Go.

## Features

- ✅ OpenAI-compatible API endpoints
- ✅ Anthropic-compatible API endpoints  
- ✅ First-class Tailscale integration with ephemeral auth keys
- ✅ Docker and docker-compose support
- ✅ Multiple deployment modes (local, Tailscale)

## Installation

### Using Go

```bash
git clone https://github.com/Tylerx404/z2api-go.git
cd z2api-go
go mod download
go run main.go
```

### Using Docker (Local Development)

For local development without Tailscale:

```bash
git clone https://github.com/Tylerx404/z2api-go.git
cd z2api-go
docker-compose -f docker-compose.local.yml up -d
```

The API will be available at `http://localhost:8080`.

### Using Docker with Tailscale (Recommended for Production)

For production deployments with secure Tailscale networking:

```bash
git clone https://github.com/Tylerx404/z2api-go.git
cd z2api-go

# Copy and configure environment variables
cp .env.example .env

# Generate a Tailscale ephemeral auth key (see below)
# Add it to your .env file as TS_AUTH_KEY

# Start services
docker-compose up -d
```

The API will be available on your Tailscale network at `http://z2api-go:8080` (or your custom hostname).

## Configuration

Copy the `.env.example` file to `.env` and edit:

```bash
cp .env.example .env
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TOKEN` | Z.ai token (leave empty for anonymous mode, set for authenticated mode) | - |
| `PORT` | Server port | `8080` |
| `DEBUG` | Enable debug mode | `false` |
| `DEBUG_MSG` | Enable debug messages | `false` |
| `THINK_TAGS_MODE` | Thinking tags processing mode (`reasoning`, `think`, `strip`, `details`) | `reasoning` |
| `MODEL` | Default model | `glm-4.7` |

### Tailscale Configuration

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `TS_AUTH_KEY` | Tailscale ephemeral auth key | **Yes** | - |
| `TS_HOSTNAME` | Hostname on Tailscale network | No | `z2api-go` |
| `TS_EXTRA_ARGS` | Additional Tailscale arguments | No | - |

## Tailscale Setup

### Why Tailscale?

Tailscale provides secure, zero-config VPN networking for your services:
- 🔒 **Secure**: WireGuard-based encryption
- 🚀 **Fast**: Direct peer-to-peer connections
- 🎯 **Simple**: No complex firewall rules or port forwarding
- 🔑 **Ephemeral Keys**: Enhanced security with temporary authentication

### Generating an Ephemeral Auth Key

1. Go to [Tailscale Admin Console → Settings → Keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Configure the key:
   - ✅ **Check "Ephemeral"** - Key is temporary and node auto-removes when offline
   - ✅ **Check "Reusable"** (optional) - Allow multiple uses of the same key
   - Set expiration (e.g., 90 days)
   - Add tags (optional, e.g., `tag:service`, `tag:api`)
4. Copy the generated key (format: `tskey-auth-xxxxx-xxxxxx`)
5. Add it to your `.env` file:
   ```
   TS_AUTH_KEY=tskey-auth-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

### Ephemeral vs Regular Keys

**Ephemeral Keys (Recommended):**
- ✅ Nodes automatically removed when disconnected
- ✅ Better security posture
- ✅ Ideal for containerized/temporary workloads
- ✅ No manual cleanup needed

**Regular Keys:**
- Nodes persist even when offline
- Require manual removal from admin console
- Better for permanent infrastructure

### Advanced Tailscale Configuration

You can customize Tailscale behavior using `TS_EXTRA_ARGS`:

```bash
# Advertise tags for ACL rules
TS_EXTRA_ARGS=--advertise-tags=tag:service,tag:production

# Accept DNS configuration from Tailscale
TS_EXTRA_ARGS=--accept-dns=true

# Advertise routes to other networks
TS_EXTRA_ARGS=--advertise-routes=10.0.0.0/24

# Multiple arguments
TS_EXTRA_ARGS=--advertise-tags=tag:api --accept-dns=true
```

### Architecture

The Tailscale integration uses a sidecar pattern:

```
┌─────────────────────────────────────┐
│  Docker Compose                      │
│  ┌─────────────────────────────┐   │
│  │  Tailscale Container        │   │
│  │  - Manages VPN connection   │   │
│  │  - Network namespace        │   │
│  └─────────────────────────────┘   │
│              ↕ (shares network)     │
│  ┌─────────────────────────────┐   │
│  │  Z2api-go Container         │   │
│  │  - API service              │   │
│  │  - Uses Tailscale network   │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Benefits:**
- Clean separation of concerns
- Easy to enable/disable Tailscale
- Reusable across different services
- Follows Docker best practices

### Accessing Your API

Once deployed with Tailscale:

1. From any device on your Tailscale network:
   ```bash
   curl http://z2api-go:8080/health
   ```

2. Use the Tailscale IP (check with `tailscale status`):
   ```bash
   curl http://100.x.y.z:8080/v1/models
   ```

3. Use MagicDNS name:
   ```bash
   curl http://z2api-go.your-tailnet.ts.net:8080/v1/chat/completions
   ```

## License

MIT License