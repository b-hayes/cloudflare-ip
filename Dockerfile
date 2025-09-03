FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron

WORKDIR /app

COPY update-cloudflare-ip.sh .
COPY run-all-updates.sh .

RUN chmod +x *.sh

# Setup cron to run every hour
RUN echo "0 * * * * /app/run-all-updates.sh >> /var/log/cloudflare-updates.log 2>&1" > /etc/crontabs/root

CMD ["crond", "-f", "-d", "8"]