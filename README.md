# Cloudflare DNS IP Updater

Updates Cloudflare DNS records with your current public IP address.

## Setup

1. Install dependencies: `sudo apt install curl jq` (or `brew install curl jq`)
2. Copy `.env.example` to `.env` and fill in your values

Get your API token at: https://dash.cloudflare.com/profile/api-tokens (needs "Zone:DNS:Edit" permissions)

## Usage

**Single site:**
```bash
./update-cloudflare-ip.sh
```

**Multiple sites:**

For multiple sites, keep shared settings in `.env` and create site-specific files with zone ID and record name.
The regular env file will be loaded before the site-specific one.

```bash
./update-cloudflare-ip.sh example.com.env
./update-cloudflare-ip.sh api.example.com.env
```

There is also a script for iterating over all env files and running the command for each one for you.
```bash
./update-all-if-ip-changed.sh
```

**Smart IP change detection:**
- Only updates DNS records if your public IP has changed since the last successful update
- Saves your current IP after successful updates in `.last_successful_ip`
- Exits early with no API calls if IP unchanged, making it efficient for frequent runs
- Use `--force` or `-f` to update anyway (ignores IP change check)

## Automation

**Docker (recommended):**
```bash
docker compose up -d
```

Runs `./update-all-if-ip-changed.sh` every 15 minutes but only updates DNS records when your IP has actually changed.

**Manual cron:**
If you dont have or want to use docker, you can schedule the script manually.

```bash
crontab -e
```

And then add this line:
```text
0 * * * * /path/to/update-all-if-ip-changed.sh
```