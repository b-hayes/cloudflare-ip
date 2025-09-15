#!/bin/bash

# Run heartbeat every 10 minutes showing countdown to next IP check
while true; do
    CURRENT_TIME=$(date +%s)
    CURRENT_MINUTE=$((10#$(date +%M)))
    CURRENT_SECOND=$((10#$(date +%S)))

    # Calculate seconds until next hour (when cron runs)
    SECONDS_UNTIL_HOUR=$(( (60 - CURRENT_MINUTE) * 60 - CURRENT_SECOND ))

    # Format time remaining
    HOURS=$(( SECONDS_UNTIL_HOUR / 3600 ))
    MINUTES=$(( (SECONDS_UNTIL_HOUR % 3600) / 60 ))
    SECONDS=$(( SECONDS_UNTIL_HOUR % 60 ))

    if [ $HOURS -gt 0 ]; then
        TIME_REMAINING="${HOURS}h ${MINUTES}m ${SECONDS}s"
    elif [ $MINUTES -gt 0 ]; then
        TIME_REMAINING="${MINUTES}m ${SECONDS}s"
    else
        TIME_REMAINING="${SECONDS}s"
    fi

    LAST_IP=$([ -f .last_successful_ip ] && cat .last_successful_ip || echo 'none')

    echo "$(date): ❤️  Cloudflare DNS updater running - Next IP check in ${TIME_REMAINING} - Last IP: ${LAST_IP}"

    sleep 600  # 10 minutes
done