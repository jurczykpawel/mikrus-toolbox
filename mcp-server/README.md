# Mikrus Toolbox MCP Server

> **Alpha** - This server is in early development. The core tools work, but expect rough edges, missing validations, and evolving APIs. Feedback and bug reports welcome via [Issues](https://github.com/pavvel11/mikrus-toolbox/issues).

MCP (Model Context Protocol) server for deploying self-hosted apps to [Mikrus](https://mikr.us) VPS servers.

Allows AI assistants (Claude Desktop, etc.) to set up SSH connections, browse available apps, deploy applications, and even install custom Docker apps - all via natural language.

## Quick Start

### 1. Build

```bash
cd mcp-server
npm install
npm run build
```

### 2. Configure Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mikrus-toolbox": {
      "command": "node",
      "args": ["/path/to/mikrus-toolbox/mcp-server/dist/index.js"]
    }
  }
}
```

### 3. Use

In Claude Desktop:

> "Set up SSH connection to my Mikrus server at srv20.mikr.us port 2222"

> "What apps can I deploy?"

> "Deploy uptime-kuma with a Cytrus domain"

> "Install Gitea on my server" *(custom app - AI researches and generates compose)*

> "Check what's running on my server"

## Prerequisites

- **Node.js 18+**
- **mikrus-toolbox** repo cloned locally
- **Mikrus VPS** account (SSH credentials from mikr.us panel)

## Available Tools (5)

### `setup_server`

Set up or test SSH connection to a Mikrus VPS.

**Setup mode** (new connection):
```
{ host: "srv20.mikr.us", port: 2222, user: "root", alias: "mikrus" }
```
Generates SSH key, writes `~/.ssh/config`, returns `ssh-copy-id` command for user to run once.

**Test mode** (existing connection):
```
{ ssh_alias: "mikrus" }
```
Tests connectivity, shows RAM, disk, running containers.

### `list_apps`

List all 25+ tested apps with metadata.

```
{ category: "no-db" }  // Optional filter: all, no-db, postgres, mysql, lightweight
```

### `deploy_app`

Deploy a tested application from the toolbox.

```
{
  app_name: "uptime-kuma",
  domain_type: "cytrus",
  domain: "auto"
}
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `app_name` | Yes | App to deploy (use `list_apps`) |
| `ssh_alias` | No | SSH alias (default: configured server) |
| `domain_type` | No | `cytrus`, `cloudflare`, or `local` |
| `domain` | No | Domain name or `auto` for Cytrus |
| `db_source` | For DB apps | `shared` or `custom` |
| `db_host/port/name/user/pass` | If custom | Database credentials |
| `port` | No | Override default port |
| `dry_run` | No | Preview without executing |
| `extra_env` | No | App-specific env vars |

### `deploy_custom_app`

Deploy ANY Docker application - not limited to the built-in list. AI researches the app, generates `docker-compose.yaml`, shows it to user for confirmation, then deploys.

```
{
  name: "gitea",
  compose: "services:\n  gitea:\n    image: gitea/gitea:latest\n    ...",
  confirmed: true,
  port: 3000
}
```

User must explicitly confirm before deployment (`confirmed: true`).

### `server_status`

Check server state: containers, RAM, disk, ports.

```
{ ssh_alias: "mikrus" }
```

## Architecture

```
Claude Desktop ←stdio→ MCP Server (local) ←shell→ deploy.sh ←SSH→ Mikrus VPS
```

The MCP server runs on your local machine:
- `setup_server` configures SSH keys and `~/.ssh/config`
- `deploy_app` shells out to `local/deploy.sh` (resource checks, DB setup, domain config)
- `deploy_custom_app` uploads compose files directly via SSH

## Smart Guidance (Roadmap)

MCP isn't just a "run commands" interface. Because the AI model sees tool descriptions, app metadata (RAM requirements, DB dependencies, ports), and server state, it can **guide the user through the entire setup** like an expert sysadmin. The key: **the model should always read the app's README first** (via `list_apps` metadata) before suggesting anything.

**Example 1: Uptime Kuma** (no database needed)

```
User: "I want to monitor my websites"
AI:   *reads apps/uptime-kuma/README.md*
      "Uptime Kuma is perfect - self-hosted monitoring dashboard
       (replaces UptimeRobot). Uses built-in SQLite, no external
       database needed. Only ~80MB RAM. Want me to install it?"
User: "Yes"
AI:   → deploy_app { app: "uptime-kuma", domain_type: "cytrus", domain: "auto" }
       "Done! Uptime Kuma is live at https://xyz.byst.re
        Create your admin account on first visit."
```

**Example 2: WordPress** (shared MySQL + Redis auto-detection)

```
User: "Set up a WordPress site"
AI:   *reads apps/wordpress/README.md*
      "WordPress Performance Edition (FPM + Nginx + Redis cache).
       Uses only ~80-100MB RAM. For the database, the free shared
       MySQL on Mikrus works fine - no need for a paid one.
       Redis for caching: I'll check if you already have Redis
       running - if yes, WordPress will connect to it; if not,
       I'll bundle redis:alpine (~96MB extra RAM)."
User: "Go ahead"
AI:   → deploy_app { app: "wordpress", domain_type: "cytrus", domain: "auto" }
       "Done! WordPress is live. Redis was bundled automatically.
        Run wp-init.sh to apply performance optimizations."
```

**Example 3: n8n** (shared DB won't work - dedicated required)

```
User: "Install n8n"
AI:   *reads apps/n8n/README.md*
      "n8n needs PostgreSQL, but the free shared DB on Mikrus won't
       work - it's PostgreSQL 12 which lacks gen_random_uuid().
       You'll need a dedicated PostgreSQL (29 zł/year for 512MB/10GB).
       Do you have one, or should I walk you through ordering?"
User: "I don't have one yet"
AI:   "Go to https://mikr.us/panel/?a=cloud and order PostgreSQL 512MB.
        Once you have the credentials, share them with me."
User: *shares credentials*
AI:   → deploy_app { app: "n8n", db_source: "custom", db_host: "...", ... }
       "Done! n8n is live. I'd recommend setting up backups too."
```

**Example 4: Postiz** (dedicated DB + Redis auto-detection)

```
User: "I need a social media scheduler"
AI:   *reads apps/postiz/README.md*
      "Postiz is a Buffer/Hootsuite alternative. It needs:
       1. Dedicated PostgreSQL (shared won't work - PG 12 limitation)
       2. Redis - I'll auto-detect: if you already have Redis running,
          Postiz will reuse it; otherwise I'll bundle redis:7.2-alpine.
       Do you have a dedicated PostgreSQL?"
User: "Yes, same one I use for n8n"
AI:   *checks apps/postiz/install.sh - uses schema separation*
      "Great - Postiz uses a separate schema, so it can share the same
       PostgreSQL instance as n8n without conflicts."
      → deploy_app { app: "postiz", db_source: "custom", db_host: "...", ... }
      "Postiz is deploying. I detected Redis from your WordPress setup,
       so Postiz will reuse it (no extra RAM). Note: first start takes
       60-90s. After that, create your admin account and disable
       registration for security."
```

**Key principle:** The model should always read the app's README (via `list_apps` metadata) before suggesting anything. READMEs contain gotchas like pgcrypto requirements, RAM limits, and Redis auto-detection that the model must communicate to the user.

Planned improvements:
- **Resource budgeting** - "You have 1.2GB free RAM. This app needs ~800MB - want to upgrade to Mikrus 3.0 first?"
- **Post-deploy checklist** - security hardening, SSL verification, backup setup, monitoring
- **Multi-app orchestration** - "Set up my complete solopreneur stack" -> deploys n8n + Listmonk + Uptime Kuma + GateFlow in the right order

## Development

```bash
npm run dev    # Run with tsx (no build needed)
npm run build  # Compile TypeScript
npm start      # Run compiled version
```

## License

MIT
