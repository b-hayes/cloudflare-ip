#!/bin/bash

set -e

# Get current public IP address
if ! CURRENT_IP=$(curl -s https://ipv4.icanhazip.com 2>&1); then
    echo "Error: Failed to fetch public IP address:" >&2
    echo "$CURRENT_IP" >&2
    exit 1
fi

# Validate IP format
if [[ ! $CURRENT_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format: $CURRENT_IP" >&2
    exit 1
fi

echo "$CURRENT_IP"