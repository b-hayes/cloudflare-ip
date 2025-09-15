#!/bin/bash

set -e

cd /app

# Start heartbeat in background
./heartbeat.sh &

# Start cron in foreground
crond -f