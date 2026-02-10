# OpenClaw Cloud Deployment Reference

## Table of Contents

- [Deployment Options](#deployment-options)
- [Docker](#docker)
- [GCP Compute Engine](#gcp-compute-engine)
- [AWS Bedrock](#aws-bedrock)
- [Fly.io](#flyio)
- [Azure (General Approach)](#azure-general-approach)
- [Remote Access](#remote-access)
- [Northflank](#northflank)
- [Nix](#nix)
- [Ansible](#ansible)
- [macOS VM](#macos-vm)
- [Universal Cloud Security Checklist](#universal-cloud-security-checklist)

## Deployment Options

| Platform | Cost | Best For |
|----------|------|----------|
| Docker (self-hosted) | Free + hosting | Full control, existing infra |
| GCP Compute Engine | ~$12/mo (e2-small) | Google Cloud users |
| AWS (EC2 + Bedrock) | Varies | AWS ecosystem, Bedrock models |
| Fly.io | ~$10-15/mo | Quick cloud deploy |
| Railway | Varies | Rapid prototyping |
| Render | Varies | Simple cloud hosting |
| Hetzner | ~$5-10/mo | European hosting, cost-conscious |
| Northflank | Varies | Managed containers |
| Nix | Free + hosting | Reproducible builds |
| Ansible | Free + hosting | Automated multi-host |
| macOS VM | Varies | iMessage channel support |

## Docker

### Containerized Gateway

```bash
git clone <openclaw-repo>
./docker-setup.sh
```

Security defaults: non-root `node` user (uid 1000), no runtime package installs.

**Environment variables:**
- `OPENCLAW_DOCKER_APT_PACKAGES` — extra system packages at build
- `OPENCLAW_EXTRA_MOUNTS` — host bind mounts (`host:container:mode`)
- `OPENCLAW_HOME_VOLUME` — named volume for persistence

### Agent Sandbox

Gateway on host; tools in Docker containers:

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main",
        scope: "session",
        workspaceAccess: "none",
        docker: {
          image: "openclaw-sandbox:bookworm-slim",
          network: "none",        // No egress
          user: "1000:1000",
          memory: "1g",
        },
        prune: { idleHours: 24, maxAgeDays: 7 },
      },
    },
  },
}
```

Setup: `scripts/sandbox-setup.sh` (one-time image build).

### Alternative Runtimes

- **Bun**: `bun install -g openclaw@latest` — experimental, faster startup
- **Node.js** (default): `npm install -g openclaw@latest`

## GCP Compute Engine

```bash
gcloud compute instances create openclaw-gateway \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB
```

- Access via SSH tunnel: `gcloud compute ssh openclaw-gateway -- -L 18789:127.0.0.1:18789`
- Use service accounts with minimal IAM permissions (avoid Owner role)
- Generate secrets: `openssl rand -hex 32`
- Never commit `.env`

State persistence: mount host dirs for `~/.openclaw/` and workspace.

## AWS Bedrock

### IAM Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:ListFoundationModels"
  ],
  "Resource": "*"
}
```

Or: `AmazonBedrockFullAccess` managed policy.

### Auth Chain
1. `AWS_BEARER_TOKEN_BEDROCK`
2. `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`
3. `AWS_PROFILE`
4. EC2 instance metadata (set `AWS_PROFILE=default` as workaround)

### Config
```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

Enable model access in AWS console first. Auto-discovery caches for 1 hour.

## Fly.io

```bash
fly launch --name my-openclaw
fly volumes create openclaw_data --size 1 --region nrt
fly secrets set ANTHROPIC_API_KEY=sk-... OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
fly deploy
```

- `internal_port` must match `--port` flag
- `OPENCLAW_STATE_DIR = "/data"` for volume persistence
- Minimum 2GB RAM (512MB crashes)
- Use `--bind lan` for Fly proxy
- Hardened: release public IPs, use SSH/WireGuard

Common issue: delete `/data/gateway.*.lock` after crash.

## Azure (General Approach)

No dedicated OpenClaw Azure guide yet:
1. Deploy on Azure VM (B1s/B2s) or Container Instances
2. Use Azure Key Vault for secrets
3. NSG: restrict inbound to SSH only
4. Access via SSH tunnel or Azure Bastion

Azure OpenAI as custom provider:
```json5
{
  models: {
    providers: {
      "azure-openai": {
        baseUrl: "https://your-resource.openai.azure.com/openai/deployments/your-deployment",
        apiKey: "$AZURE_OPENAI_API_KEY",
      },
    },
  },
}
```

## Remote Access

### Tailscale Serve (Preferred)
Keeps `gateway.bind: "loopback"`. No public IP exposure. Best security.

### SSH Tunnel
```bash
ssh -N -L 18789:127.0.0.1:18789 user@gateway-host
```

Remote CLI config:
```json5
{
  gateway: {
    mode: "remote",
    remote: { url: "ws://127.0.0.1:18789", token: "your-token" },
  },
}
```

### Security Rules
- **Never** bind `0.0.0.0` without auth + firewall
- **Always** set `gateway.auth.token` for non-loopback
- **Prefer**: Tailscale > SSH > LAN > public
- Optional: TLS fingerprint pinning via `gateway.remote.tlsFingerprint`

## Northflank

Managed container platform with built-in secret management:

1. Create service from Docker image or linked repo
2. Add persistent volume for `~/.openclaw/`
3. Configure secrets via Northflank secret groups
4. Set `OPENCLAW_STATE_DIR=/data` for volume persistence
5. Bind to internal port, use Northflank networking for access

- Minimum 512MB RAM (1GB recommended)
- Use health check endpoint: `GET /health`

## Nix

Reproducible builds with Nix flakes:

```bash
nix run github:openclaw/openclaw -- gateway --port 18789
```

- Declarative: add to `flake.nix` or `configuration.nix`
- NixOS module available for systemd integration
- Pins exact Node.js + OpenClaw versions

## Ansible

Automated deployment across multiple hosts:

```bash
# Community playbook
ansible-galaxy install openclaw.gateway
ansible-playbook -i inventory.yml openclaw-deploy.yml
```

- Handles: Node.js install, OpenClaw install, systemd service, firewall, secrets
- Supports: Debian/Ubuntu, RHEL/Fedora, macOS
- Variables: `openclaw_port`, `openclaw_state_dir`, `openclaw_auth_token`

## macOS VM

Required for iMessage channel (needs macOS + Full Disk Access):

- **UTM/Parallels**: Run macOS VM on Apple Silicon
- **Tart**: Headless macOS VMs for CI/server use
- Grant Full Disk Access to Terminal/Node for iMessage DB access
- Install `imsg` binary for iMessage integration
- SSH tunnel or Tailscale for remote access

## Universal Cloud Security Checklist

- [ ] Generate tokens: `openssl rand -hex 32`
- [ ] Secrets in platform secret manager (not config files)
- [ ] Bind to loopback; SSH/Tailscale for remote
- [ ] File permissions: config `600`, state dir `700`
- [ ] Full-disk encryption on host
- [ ] Non-root user for gateway
- [ ] Run `openclaw security audit --deep` after deploy
- [ ] Set up health monitoring
- [ ] Keep updated: `openclaw update`
- [ ] Backup `~/.openclaw/` (encrypt backups)
