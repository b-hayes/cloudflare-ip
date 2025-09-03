#!/bin/bash

set -e

# Load shared variables from .env first (always)
if [ -f ".env" ]; then
    echo "Loading environment variables from .env"
    source ".env"
fi

# Load site-specific variables if provided (can override shared ones)
if [ $# -eq 1 ]; then
    SITE_ENV_FILE="$1"
    if [ -f "$SITE_ENV_FILE" ]; then
        echo "Loading site-specific environment variables from $SITE_ENV_FILE"
        source "$SITE_ENV_FILE"
    else
        echo "Error: Site-specific .env file '$SITE_ENV_FILE' not found"
        exit 1
    fi
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
echo "Getting current public IP address..."
if ! CURRENT_IP=$(curl -s https://ipv4.icanhazip.com 2>&1); then
    echo "Error: Failed to fetch public IP address:"
    echo "$CURRENT_IP"
    exit 1
fi

if [ -z "$CURRENT_IP" ]; then
    echo "Error: Received empty response when fetching public IP address"
    exit 1
fi

echo "Current public IP: $CURRENT_IP"

# Get existing DNS record
echo "Checking existing DNS record for $CLOUDFLARE_RECORD_NAME..."
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
    echo "DNS record not found. Creating new record..."
    
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
        echo "✓ DNS record created successfully"
        echo "Record: $CLOUDFLARE_RECORD_NAME → $CURRENT_IP"
    else
        echo "Error: Failed to create DNS record"
        echo "$CREATE_RESPONSE" | jq -r '.errors[]'
        exit 1
    fi
else
    echo "Found existing DNS record: $CLOUDFLARE_RECORD_NAME → $RECORD_IP"
    
    if [ "$RECORD_IP" = "$CURRENT_IP" ]; then
        echo "✓ DNS record is already up to date"
    else
        echo "Updating DNS record from $RECORD_IP to $CURRENT_IP..."
        
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
            echo "✓ DNS record updated successfully"
            echo "Record: $CLOUDFLARE_RECORD_NAME → $CURRENT_IP"
        else
            echo "Error: Failed to update DNS record"
            echo "$UPDATE_RESPONSE" | jq -r '.errors[]'
            exit 1
        fi
    fi
fi