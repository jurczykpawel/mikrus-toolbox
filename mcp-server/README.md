# Mikrus Toolbox MCP Server

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

## Development

```bash
npm run dev    # Run with tsx (no build needed)
npm run build  # Compile TypeScript
npm start      # Run compiled version
```

## License

MIT
