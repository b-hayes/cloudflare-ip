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
./run-all-updates.sh
```

## Automation

**Docker (recommended):**
```bash
docker compose up -d
```

Runs `./run-all-updates.sh` hourly to keep all your websites up to date.

**Manual cron:**
If you dont have or want to use docker, you can schedule the script manually.

```bash
crontab -e
```

And then add this line:
```text
0 * * * * /path/to/run-all-updates.sh
```