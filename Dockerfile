FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron

WORKDIR /app

# Setup cron to run every hour
RUN echo "0 * * * * /app/update-all-if-ip-changed.sh 2>&1 | tee -a /app/updates.log" > /etc/crontabs/root

CMD ["./start.sh"]