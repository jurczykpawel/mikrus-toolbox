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

**Example 1: Uptime Kuma** (simple, no database needed)

```
User: "I want to monitor my websites"
AI:   *reads apps/uptime-kuma/README.md*
      "Uptime Kuma is perfect for that - it's a self-hosted monitoring
       dashboard (replaces UptimeRobot). Uses built-in SQLite, no
       external database needed. Only ~80MB RAM. Want me to install it?"
User: "Yes"
AI:   → deploy_app { app: "uptime-kuma", domain_type: "cytrus", domain: "auto" }
       "Done! Uptime Kuma is live at https://xyz.byst.re
        Create your admin account on first visit."
```

**Example 2: n8n** (requires dedicated database)

```
User: "Install n8n"
AI:   *reads apps/n8n/README.md*
      "n8n requires PostgreSQL with the pgcrypto extension.
       The free shared DB on Mikrus won't work - no permission
       to create extensions. You'll need a dedicated PostgreSQL
       instance (29 zł/year for 512MB / 10GB).
       Do you already have one, or should I walk you through ordering it?"
User: "I don't have one yet"
AI:   "Go to https://mikr.us/panel/?a=cloud and order PostgreSQL 512MB.
        Once you have the credentials (host, user, password, database),
        share them with me and I'll deploy n8n."
User: *shares credentials*
AI:   → deploy_app { app: "n8n", db_source: "custom", db_host: "...", ... }
       "Done! n8n is live. I'd also recommend setting up backups."
```

Planned improvements:
- **Dependency awareness** - "Postiz needs Redis. I'll bundle it automatically."
- **Resource budgeting** - "You have 1.2GB free RAM. This app needs ~800MB - want to upgrade to Mikrus 3.0 first?"
- **Post-deploy checklist** - security hardening, SSL verification, backup setup, monitoring
- **Multi-app orchestration** - "Set up my complete solopreneur stack" -> deploys n8n + Listmonk + Uptime Kuma + GateFlow in the right order
- **README-driven intelligence** - model reads each app's README before proposing config, catching gotchas like pgcrypto requirements or RAM limits

## Development

```bash
npm run dev    # Run with tsx (no build needed)
npm run build  # Compile TypeScript
npm start      # Run compiled version
```

## License

MIT
