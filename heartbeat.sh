#!/bin/bash

set -e

# Single heartbeat execution for cron
CURRENT_MINUTE=$((10#$(date +%M)))
CURRENT_SECOND=$((10#$(date +%S)))

# Read the actual cron schedule for update-all-if-ip-changed.sh
CRON_SCHEDULE=$(grep "update-all-if-ip-changed.sh" /etc/crontabs/root | awk '{print $1, $2, $3, $4, $5}')

# Extract minute and hour from cron schedule (format: "minute hour day month dow")
CRON_MINUTE=$(echo $CRON_SCHEDULE | awk '{print $1}')
CRON_HOUR=$(echo $CRON_SCHEDULE | awk '{print $2}')

# Handle */N minute syntax
if [[ "$CRON_MINUTE" == */[0-9]* ]]; then
    INTERVAL=${CRON_MINUTE#*/}
    # Calculate next run based on interval
    NEXT_RUN_MINUTE=$(( (CURRENT_MINUTE / INTERVAL + 1) * INTERVAL ))
    if [ $NEXT_RUN_MINUTE -ge 60 ]; then
        NEXT_RUN_MINUTE=$((NEXT_RUN_MINUTE - 60))
        SECONDS_UNTIL_NEXT=$(( (60 - CURRENT_MINUTE + NEXT_RUN_MINUTE) * 60 - CURRENT_SECOND ))
    else
        SECONDS_UNTIL_NEXT=$(( (NEXT_RUN_MINUTE - CURRENT_MINUTE) * 60 - CURRENT_SECOND ))
    fi
elif [ "$CRON_HOUR" = "*" ]; then
    # Runs every hour at specified minute
    if [ $CURRENT_MINUTE -lt $CRON_MINUTE ]; then
        # Next run is this hour
        SECONDS_UNTIL_NEXT=$(( (CRON_MINUTE - CURRENT_MINUTE) * 60 - CURRENT_SECOND ))
    else
        # Next run is next hour
        SECONDS_UNTIL_NEXT=$(( (60 - CURRENT_MINUTE + CRON_MINUTE) * 60 - CURRENT_SECOND ))
    fi
else
    # Runs at specific hour (daily/etc) - simplified calculation for next occurrence
    CURRENT_HOUR=$((10#$(date +%H)))
    if [ $CURRENT_HOUR -lt $CRON_HOUR ] || ([ $CURRENT_HOUR -eq $CRON_HOUR ] && [ $CURRENT_MINUTE -lt $CRON_MINUTE ]); then
        # Next run is today
        MINUTES_UNTIL=$(( (CRON_HOUR - CURRENT_HOUR) * 60 + CRON_MINUTE - CURRENT_MINUTE ))
        SECONDS_UNTIL_NEXT=$(( MINUTES_UNTIL * 60 - CURRENT_SECOND ))
    else
        # Next run is tomorrow
        MINUTES_UNTIL=$(( (24 - CURRENT_HOUR + CRON_HOUR) * 60 + CRON_MINUTE - CURRENT_MINUTE ))
        SECONDS_UNTIL_NEXT=$(( MINUTES_UNTIL * 60 - CURRENT_SECOND ))
    fi
fi

# Format time remaining
HOURS=$(( SECONDS_UNTIL_NEXT / 3600 ))
MINUTES=$(( (SECONDS_UNTIL_NEXT % 3600) / 60 ))
SECONDS=$(( SECONDS_UNTIL_NEXT % 60 ))

if [ $HOURS -gt 0 ]; then
    TIME_REMAINING="${HOURS}h ${MINUTES}m ${SECONDS}s"
elif [ $MINUTES -gt 0 ]; then
    TIME_REMAINING="${MINUTES}m ${SECONDS}s"
else
    TIME_REMAINING="${SECONDS}s"
fi

echo "Heartbeat: Next IP check in ${TIME_REMAINING}"