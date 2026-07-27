# OmniRoute

Unified AI proxy for Home Assistant. Route any LLM through one endpoint — 250+ providers, 90+ free tiers.

## Installation

1. Add the repository: `https://github.com/grunjol/hassio-repository`
2. Find "OmniRoute" in the App Store and install
3. Configure the options below and start the app

## Configuration

### Option: `PORT`

The port OmniRoute listens on. Default is `20128`.

### Option: `AUTH_COOKIE_SECURE`

Set to `true` when OmniRoute is behind an HTTPS reverse proxy (Nginx, Caddy, Cloudflare Tunnel). This enables the `Secure` flag on session cookies. Default is `false`.

### Option: `OMNIROUTE_ALLOW_PRIVATE_PROVIDER_URLS`

Set to `true` to connect to local/self-hosted providers like Ollama, vLLM, LM Studio, or Llamafile. Default is `false` (blocks private IP ranges for security).

### Option: `OMNIROUTE_MEMORY_MB`

Maximum Node.js heap memory in megabytes. Default is `1024` (1 GB). Increase to `2048` or higher if you experience out-of-memory errors with large prompts, fusion combos, or many concurrent connections.

## First-time setup

1. Start the app
2. Open the dashboard at `http://homeassistant.local:20128` (replace with your HA host)
3. Login with the default password: `CHANGEME`
4. **Change the password immediately** from Settings → Security
5. Go to **Providers** and add your API keys for OpenAI, Anthropic, Google, etc.
6. All secrets (JWT, encryption keys) are auto-generated on first boot and persisted in `/app/data/`

## Connecting your tools

Once configured, point any OpenAI-compatible tool to:

```
http://homeassistant.local:20128/v1
```

Use `auto` as the model name to let OmniRoute pick the best provider automatically.

### Supported tools

- Claude Code, Codex, Cursor, Cline, Copilot, Antigravity
- Any tool that supports custom OpenAI-compatible endpoints
- Home Assistant voice assistants and AI integrations
- [Full list of 24+ supported CLIs](https://github.com/diegosouzapw/OmniRoute#-compatible-clis--coding-agents)

## Data location

| Data | Path |
|------|------|
| Database (SQLite) | `/app/data/storage.sqlite` |
| Auto-generated secrets | `/app/data/server.env` |
| Encrypted API keys | Stored inside `storage.sqlite` |

## Upgrading

The app version follows the upstream OmniRoute version. Your data, keys, and configuration are preserved in `/app/data/` across upgrades.

## Support

- [OmniRoute Documentation](https://github.com/diegosouzapw/OmniRoute)
- [OmniRoute Discord](https://discord.gg/EkzRkpzKYt)
- [App Repository](https://github.com/grunjol/addon-omniroute)
