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

## Automation

Add to crontab for automatic updates:
```bash
*/5 * * * * /path/to/update-cloudflare-ip.sh
```