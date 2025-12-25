# Tailscale Integration Guide

This document provides detailed information about the Tailscale integration in z2api-go.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

## Overview

Z2api-go includes first-class Tailscale support for secure, private networking. This integration:

- Uses **ephemeral auth keys** for enhanced security
- Implements Docker **sidecar pattern** for clean architecture
- Provides **zero-config networking** once Tailscale is set up
- Supports **reusable configuration** across deployments

## Quick Start

### 1. Generate a Tailscale Auth Key

Visit: https://login.tailscale.com/admin/settings/keys

Create a new auth key with:
- ✅ **Ephemeral** enabled (recommended)
- ✅ **Reusable** enabled (optional, useful for testing)
- Expiration: 90 days (or your preference)
- Tags: `tag:service` or `tag:api` (optional, for ACLs)

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and add your auth key:
```env
TS_AUTH_KEY=tskey-auth-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TS_HOSTNAME=z2api-go
```

### 3. Deploy

```bash
docker-compose up -d
```

### 4. Verify Connection

```bash
# Check Tailscale logs
docker logs z2api-go-tailscale

# Test API access via Tailscale
curl http://z2api-go:8080/health
```

## Configuration

### Required Variables

#### `TS_AUTH_KEY`
Your Tailscale authentication key.

**Format:** `tskey-auth-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**Security:** 
- Use ephemeral keys when possible
- Rotate keys regularly
- Never commit keys to version control

### Optional Variables

#### `TS_HOSTNAME`
Custom hostname for your service on the Tailscale network.

**Default:** `z2api-go`

**Example:**
```env
TS_HOSTNAME=z2api-production
```

**Access:**
- Via hostname: `http://z2api-production:8080`
- Via MagicDNS: `http://z2api-production.your-tailnet.ts.net:8080`

#### `TS_EXTRA_ARGS`
Additional arguments passed to `tailscale up`.

**Common uses:**

1. **Advertise tags** (for ACL management):
   ```env
   TS_EXTRA_ARGS=--advertise-tags=tag:service,tag:production
   ```

2. **Accept DNS from Tailscale**:
   ```env
   TS_EXTRA_ARGS=--accept-dns=true
   ```

3. **Advertise subnet routes**:
   ```env
   TS_EXTRA_ARGS=--advertise-routes=10.0.0.0/24
   ```

4. **Multiple arguments**:
   ```env
   TS_EXTRA_ARGS=--advertise-tags=tag:api --accept-dns=true --ssh
   ```

## Security Best Practices

### 1. Use Ephemeral Keys

Ephemeral keys ensure nodes are automatically removed when disconnected:

```
✅ Ephemeral: Node auto-removes after disconnect
❌ Regular: Node persists, requires manual cleanup
```

### 2. Use Reusable Keys Carefully

Reusable keys can be used multiple times but should be:
- Rotated regularly
- Used only in trusted environments
- Combined with ephemeral mode

### 3. Implement ACL Rules

Use Tailscale ACLs to control access:

```json
{
  "tagOwners": {
    "tag:service": ["autogroup:admin"],
    "tag:api": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:api:8080"]
    }
  ]
}
```

### 4. Never Commit Auth Keys

Always use:
- Environment variables
- Docker secrets
- Secret management services

Never:
- Commit `.env` files with real keys
- Hardcode keys in Dockerfiles
- Share keys in public repositories

### 5. Rotate Keys Regularly

Set appropriate expiration times:
- Development: 30-90 days
- Production: 30 days
- CI/CD: 1-7 days

## Troubleshooting

### Service Won't Start

**Symptom:** Container exits immediately

**Check:**
```bash
docker logs z2api-go-tailscale
```

**Common causes:**
1. Missing `TS_AUTH_KEY`
   - Solution: Add key to `.env` file
2. Invalid auth key
   - Solution: Generate new key from Tailscale admin
3. Network permissions
   - Solution: Ensure `NET_ADMIN` and `NET_RAW` capabilities

### Can't Access API

**Symptom:** Connection refused or timeout

**Check:**
1. Verify Tailscale connection:
   ```bash
   docker exec z2api-go-tailscale tailscale status
   ```

2. Check if service is running:
   ```bash
   docker ps | grep z2api-go
   ```

3. Verify network mode:
   ```bash
   docker inspect z2api-go | grep NetworkMode
   # Should show: "service:z2api-go-tailscale"
   ```

4. Test from Tailscale network:
   ```bash
   tailscale ping z2api-go
   curl http://z2api-go:8080/health
   ```

### Permission Denied Errors

**Symptom:** `operation not permitted` or similar

**Solution:** Ensure proper Docker capabilities:
```yaml
cap_add:
  - NET_ADMIN
  - NET_RAW
```

### Hostname Conflicts

**Symptom:** Hostname already taken

**Solution:** Choose a unique hostname:
```env
TS_HOSTNAME=z2api-go-prod-01
```

## Advanced Topics

### Using with Docker Swarm

For Docker Swarm deployments:

```yaml
version: "3.8"
services:
  tailscale:
    image: z2api-go-tailscale
    deploy:
      mode: global
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TS_AUTH_KEY=${TS_AUTH_KEY}
      - TS_HOSTNAME=${TS_HOSTNAME}
```

### Using with Kubernetes

Consider using the [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator) instead of the sidecar pattern.

### Multiple Services Behind Tailscale

Share Tailscale network across multiple services:

```yaml
services:
  tailscale:
    # ... tailscale config ...
  
  z2api-go:
    network_mode: "service:tailscale"
    # ...
  
  another-service:
    network_mode: "service:tailscale"
    # ...
```

### Custom Tailscale Version

Pin specific Tailscale version:

```dockerfile
FROM tailscale/tailscale:v1.56.1
```

### Monitoring

Monitor Tailscale connection:

```bash
# View status
docker exec z2api-go-tailscale tailscale status

# View network info
docker exec z2api-go-tailscale tailscale netcheck

# View logs
docker logs -f z2api-go-tailscale
```

### Backup and Recovery

Tailscale state is persisted in the `tailscale-state` volume:

```bash
# Backup state
docker run --rm -v z2api-go_tailscale-state:/data -v $(pwd):/backup alpine tar czf /backup/tailscale-state.tar.gz /data

# Restore state
docker run --rm -v z2api-go_tailscale-state:/data -v $(pwd):/backup alpine tar xzf /backup/tailscale-state.tar.gz -C /
```

## References

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Tailscale + Docker Best Practices](https://tailscale.com/kb/1282/docker)
- [Ephemeral Nodes](https://tailscale.com/kb/1111/ephemeral-nodes)
- [ACL Documentation](https://tailscale.com/kb/1018/acls)
- [Auth Keys](https://tailscale.com/kb/1085/auth-keys)

## Support

For issues specific to:
- **Tailscale integration**: Open an issue in this repository
- **Tailscale service**: Visit [Tailscale Support](https://tailscale.com/contact/support)
