FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron

WORKDIR /app

# Setup cron jobs
RUN echo "*/15 * * * * /app/update-all-if-ip-changed.sh > /proc/1/fd/1 2>&1 | tee -a /app/updates.log" > /etc/crontabs/root && \
    echo "* * * * * /app/heartbeat.sh > /proc/1/fd/1 2>&1" >> /etc/crontabs/root

CMD ["./start.sh"]