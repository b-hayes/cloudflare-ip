#!/bin/bash

set -e

cd /app

echo "$(date): Cloudflare DNS updater has started."
echo "$(date): Cron schedule:"
cat /etc/crontabs/root

# Start cron in foreground
exec crond -f