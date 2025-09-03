#!/bin/bash

set -e

echo "$(date): Starting Cloudflare DNS updates"

cd /app

# Find all .env files that don't end with .example
for env_file in *.env; do
    if [[ -f "$env_file" && "$env_file" != *.example ]]; then
        echo "$(date): Processing $env_file"
        if [[ "$env_file" == ".env" ]]; then
            # For the base .env file, run without parameters
            ./update-cloudflare-ip.sh
        else
            # For site-specific files, pass the filename
            ./update-cloudflare-ip.sh "$env_file"
        fi
        echo "$(date): Completed $env_file"
        echo "---"
    fi
done

echo "$(date): All updates completed"