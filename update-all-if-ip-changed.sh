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

cd /app

# Get public IP once
if ! CURRENT_IP=$(./get-public-ip.sh 2>&1); then
    echo "Error: Failed to fetch public IP address:"
    echo "$CURRENT_IP"
    exit 1
fi
echo "$(date) IP CHECK: Current public IP is $CURRENT_IP"

# Check if IP has changed since last successful update
LAST_IP_FILE=".last_update_ip"
FAILED_SITES_FILE=".failed_sites"
RETRY_FAILED_ONLY=false

if [[ -f "$LAST_IP_FILE" && "$FORCE_UPDATE" == false ]]; then
    LAST_IP=$(cat "$LAST_IP_FILE" 2>/dev/null || echo "")
    if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
        if [[ -f "$FAILED_SITES_FILE" ]]; then
            echo "IP unchanged but retrying failed sites from previous run."
            RETRY_FAILED_ONLY=true
        else
            echo "IP has not changed skipping update."
            exit 0
        fi
    else
        echo "IP has changed from $LAST_IP to $CURRENT_IP"
    fi
else
  echo "No previous IP recorded"
fi

echo "☁️  Starting Cloudflare DNS updates..."

# Track failed sites
FAILED_SITES=()

# Determine which files to process
if [[ "$RETRY_FAILED_ONLY" == true ]]; then
    mapfile -t ENV_FILES < "$FAILED_SITES_FILE"
else
    ENV_FILES=(*.env)
fi

# Process .env files
for env_file in "${ENV_FILES[@]}"; do
    if [[ -f "$env_file" ]]; then
        # Skip base .env if there are multiple .env files there will likely be one for each site.
        if [[ "$env_file" == ".env" && ${#ENV_FILES[@]} -gt 1 && "$RETRY_FAILED_ONLY" == false ]]; then
            continue
        fi

        if [[ "$env_file" == ".env" ]]; then
            # For the base .env file, run without env file parameter
            if ! ./update-cloudflare-ip.sh --ip="$CURRENT_IP"; then
                FAILED_SITES+=("$env_file")
            fi
        else
            # For site-specific files, pass the filename and IP
            if ! ./update-cloudflare-ip.sh "$env_file" --ip="$CURRENT_IP"; then
                FAILED_SITES+=("$env_file")
            fi
        fi
    fi
done

# Save IP and manage failed sites list
if [[ ${#FAILED_SITES[@]} -eq 0 ]]; then
    echo "$CURRENT_IP" > "$LAST_IP_FILE"
    rm -f .failed_sites 2>/dev/null
    echo "All updates completed successfully. IP $CURRENT_IP recorded."
else
    echo "$CURRENT_IP" > "$LAST_IP_FILE"
    printf '%s\n' "${FAILED_SITES[@]}" > .failed_sites
    echo "Updates completed with ${#FAILED_SITES[@]} failures. Failed sites saved for retry."
    exit 1
fi