# Mikrus Toolbox - Archived

> **This project has been merged into [StackPilot](https://github.com/jurczykpawel/stackpilot).**
> All Mikrus-specific features (Cytrus domains, shared databases, free backup) are now available as a provider plugin in StackPilot.

## Migration

If you are currently using mikrus-toolbox, switch to StackPilot:

```bash
# Option 1: Fresh clone
git clone https://github.com/jurczykpawel/stackpilot.git
cd stackpilot

# Option 2: Change remote (if you cloned mikrus-toolbox)
cd mikrus-toolbox
git remote set-url origin https://github.com/jurczykpawel/stackpilot.git
git pull origin main
```

### What changed?

| mikrus-toolbox | StackPilot |
|---|---|
| Polish only | English default, Polish via `TOOLBOX_LANG=pl` |
| Mikrus-specific code in core | Mikrus is a provider plugin (auto-detected) |
| `--ssh=mikrus` default | `--ssh=vps` default |
| `--domain-type=cytrus` | `--domain-type=cytrus` (unchanged) |
| `--db-source=shared` | `--db-source=shared` (unchanged) |
| Config in `~/.config/mikrus/` | Config in `~/.config/stackpilot/` |

### Mikrus features in StackPilot

All Mikrus features work exactly the same — they are auto-detected when `/klucz_api` exists on your server:

- Free `.byst.re` subdomains (Cytrus)
- Shared PostgreSQL/MySQL via API
- Free 200MB backup
- Mikrus-specific upgrade suggestions

### Polish language

```bash
# Set Polish as default
echo "TOOLBOX_LANG=pl" >> ~/.config/stackpilot/config

# Or per-command
TOOLBOX_LANG=pl ./local/deploy.sh n8n
```

## Links

- **StackPilot**: https://github.com/jurczykpawel/stackpilot
- **Mikrus**: https://mikr.us/?r=pavvel
