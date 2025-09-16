# Cloudflare DNS IP Updater

Updates Cloudflare DNS records with your current public IP address.

## Setup

1. Install dependencies: `sudo apt install curl jq` (or `brew install curl jq`)
2. Copy `.env.example` to `.env` and fill in your values

Get your API token at: https://dash.cloudflare.com/profile/api-tokens (needs "Zone:DNS:Edit" permissions)

## Setup

Copy the [.env.example](.env.example) to `.env` and fill in your values.`

For multiple sites, keep shared settings in `.env` and create another env file for each site with the specific zone ID and record name.

EG: example.com.env or cats.funny.com.env


## Running the updates.

Updates are run via bash scripts, but a docker container is also provided to atomate the process.

### Automated via Docker (recommended)
```bash
docker compose up -d
```
This will check for public IP change every 15 minutes and update DNS records if needed.

### Manually updating

Single update:

```bash
./update-cloudflare-ip.sh #reads the .env file for credentials.
```
You can also specify the Ip address manually if needed.
```shell
./update-cloudflare-ip.sh --ip="1.2.3.4"
```

You can specify a specific env file to use for different sites, the base `.env` file is still used for shared credentials
and the specific env file can override those values for a specific site.

```bash
./update-cloudflare-ip.sh example.com.env
./update-cloudflare-ip.sh api.example.com.env
```

### Updating all sites at once
There is also a script for iterating over all env files in the current folder and updating all sites in one go.

```bash
./update-all-if-ip-changed.sh
```

This is what the docker container runs every 15 minutes.

- Only updates DNS records if your public IP has changed since the last successful update
- Saves your current IP after successful updates in `.last_successful_ip` for the aforementioned check
- Exits early with no API calls if IP unchanged, making it efficient for frequent runs
- Use `--force` or `-f` to update anyway (ignores IP change check)

### Manual Automation

If you don't have or want to use docker, you can schedule the script manually on linux via cron.

```bash
crontab -e
```

And then add this line:
```text
0 * * * * /path/to/update-all-if-ip-changed.sh
```