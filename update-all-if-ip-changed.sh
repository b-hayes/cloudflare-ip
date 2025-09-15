#!/bin/bash

set -e

# Parse arguments
FORCE_UPDATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_UPDATE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-f|--force]"
            exit 1
            ;;
    esac
done

echo "$(date): Starting Cloudflare DNS updates..."

cd /app

# Get public IP once
if ! CURRENT_IP=$(./get-public-ip.sh 2>&1); then
    echo "Error: Failed to fetch public IP address:"
    echo "$CURRENT_IP"
    exit 1
fi
echo "Current public IP: $CURRENT_IP"

# Check if IP has changed since last successful update
LAST_IP_FILE=".last_successful_ip"
if [[ -f "$LAST_IP_FILE" && "$FORCE_UPDATE" == false ]]; then
    LAST_IP=$(cat "$LAST_IP_FILE" 2>/dev/null || echo "")
    if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
        echo "No updates required, IP address has not changed since last update."
        exit 0
    fi
    echo "IP changed from $LAST_IP to $CURRENT_IP, proceeding with updates..."
fi

# Track if all updates succeed
ALL_UPDATES_SUCCESSFUL=true

# Find all .env files that don't end with .example
for env_file in *.env; do
    if [[ -f "$env_file" && "$env_file" != *.example ]]; then
        echo "Processing $env_file"
        if [[ "$env_file" == ".env" ]]; then
            # For the base .env file, run without env file parameter
            if ! ./update-cloudflare-ip.sh --ip="$CURRENT_IP"; then
                ALL_UPDATES_SUCCESSFUL=false
                echo "Failed to update $env_file"
            fi
        else
            # For site-specific files, pass the filename and IP
            if ! ./update-cloudflare-ip.sh "$env_file" --ip="$CURRENT_IP"; then
                ALL_UPDATES_SUCCESSFUL=false
                echo "Failed to update $env_file"
            fi
        fi
        echo "Completed $env_file"
        echo "---"
    fi
done

# Only save the IP if all updates were successful
if [[ "$ALL_UPDATES_SUCCESSFUL" == true ]]; then
    echo "$CURRENT_IP" > "$LAST_IP_FILE"
    echo "All updates completed successfully. IP $CURRENT_IP recorded for future reference."
else
    echo "Some updates failed. IP not recorded to ensure retry on next run."
    exit 1
fi