#!/bin/bash

set -e

# Load shared variables from .env first (always)
if [ -f ".env" ]; then
    source ".env"
fi

# Parse arguments
SITE_ENV_FILE=""
PROVIDED_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            PROVIDED_IP="$2"
            shift 2
            ;;
        --ip=*)
            PROVIDED_IP="${1#*=}"
            shift
            ;;
        *.env)
            SITE_ENV_FILE="$1"
            shift
            ;;
        *)
            # Assume it's a site env file for backward compatibility
            SITE_ENV_FILE="$1"
            shift
            ;;
    esac
done

# Load site-specific variables if provided (can override shared ones)
if [ -n "$SITE_ENV_FILE" ]; then
    if [ -f "$SITE_ENV_FILE" ]; then
        source "$SITE_ENV_FILE"
        SITE_NAME="${SITE_ENV_FILE%.env}"
    else
        echo "Error: Site-specific .env file '$SITE_ENV_FILE' not found"
        exit 1
    fi
else
    SITE_NAME="base"
fi

# Check required environment variables
if [ -z "$CLOUDFLARE_EMAIL" ]; then
    echo "Error: CLOUDFLARE_EMAIL environment variable is required"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_KEY" ]; then
    echo "Error: CLOUDFLARE_API_KEY environment variable is required"
    exit 1
fi

if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo "Error: CLOUDFLARE_ZONE_ID environment variable is required"
    exit 1
fi

if [ -z "$CLOUDFLARE_RECORD_NAME" ]; then
    echo "Error: CLOUDFLARE_RECORD_NAME environment variable is required"
    exit 1
fi


# Set defaults
CLOUDFLARE_RECORD_TYPE="${CLOUDFLARE_RECORD_TYPE:-A}"
CLOUDFLARE_TTL="${CLOUDFLARE_TTL:-300}"

# Get current public IP
if [ -n "$PROVIDED_IP" ]; then
    CURRENT_IP="$PROVIDED_IP"
else
    if ! CURRENT_IP=$(./get-public-ip.sh 2>&1); then
        echo "Error: Failed to fetch public IP address:"
        echo "$CURRENT_IP"
        exit 1
    fi
fi

echo -e "Update \033[33m$SITE_NAME\033[0m with \033[33m$CURRENT_IP\033[0m ..."

# Get existing DNS record
RECORD_RESPONSE=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$CLOUDFLARE_RECORD_NAME&type=$CLOUDFLARE_RECORD_TYPE" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

# Check if API call was successful
SUCCESS=$(echo "$RECORD_RESPONSE" | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to fetch DNS records"
    echo "$RECORD_RESPONSE" | jq -r '.errors[]'
    exit 1
fi

# Get record ID and current IP from response
RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id // empty')
RECORD_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content // empty')

if [ -z "$RECORD_ID" ]; then
    # Create new DNS record
    CREATE_RESPONSE=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"$CLOUDFLARE_RECORD_TYPE\",
            \"name\": \"$CLOUDFLARE_RECORD_NAME\",
            \"content\": \"$CURRENT_IP\",
            \"ttl\": $CLOUDFLARE_TTL
        }")

    SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
        echo -e "\033[32m✓ Success\033[0m"
    else
        echo -e "\033[31m✗ Failed\033[0m"
        echo "$CREATE_RESPONSE" | jq -r '.errors[]'
        exit 1
    fi
else
    if [ "$RECORD_IP" = "$CURRENT_IP" ]; then
        echo -e "\033[32m✓ Already up to date\033[0m"
    else
        # Update existing DNS record
        UPDATE_RESPONSE=$(curl -s -X PATCH \
            "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$RECORD_ID" \
            -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{
                \"type\": \"$CLOUDFLARE_RECORD_TYPE\",
                \"name\": \"$CLOUDFLARE_RECORD_NAME\",
                \"content\": \"$CURRENT_IP\",
                \"ttl\": $CLOUDFLARE_TTL
            }")

        SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
        if [ "$SUCCESS" = "true" ]; then
            echo -e "\033[32m✓ Success\033[0m"
        else
            echo -e "\033[31m✗ Failed\033[0m"
            echo "$UPDATE_RESPONSE" | jq -r '.errors[]'
            exit 1
        fi
    fi
fi