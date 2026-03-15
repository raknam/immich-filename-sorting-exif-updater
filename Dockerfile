FROM alpine:3.21

# Install supercronic (lightweight cron for Docker)
ARG TARGETARCH
ARG SUPERCRONIC_VERSION=v0.2.44
RUN wget -q "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" \
      -O /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

RUN apk add --no-cache perl exiftool coreutils

COPY entrypoint.sh process.sh /
RUN chmod +x /entrypoint.sh /process.sh

WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
