FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron

WORKDIR /app

# Setup cron to run every hour
RUN echo "0 * * * * /app/run-all-updates.sh >> /var/log/cloudflare-updates.log 2>&1" > /etc/crontabs/root

CMD ["crond", "-f"]