# renovate: datasource=docker depName=ghcr.io/usa-reddragon/steamcmd
ARG STEAMCMD_VERSION=main
ARG STEAMCMD_REF=sha256:5372999d602842956f7405b26e6be27f7871aa5c411d94062f5168d12abc6d27
ARG STEAMCMD_IMAGE=ghcr.io/usa-reddragon/steamcmd:${STEAMCMD_VERSION}@${STEAMCMD_REF}

FROM golang:1.24.5-alpine as rcon-cli_builder

# RCON: Latest releases available at https://github.com/gorcon/rcon-cli/releases
# renovate: datasource=github-tags depName=gorcon/rcon-cli
ARG RCON_VERSION=v0.10.3

WORKDIR /build

ENV CGO_ENABLED=0
RUN wget -q https://github.com/gorcon/rcon-cli/archive/refs/tags/${RCON_VERSION}.tar.gz -O rcon.tar.gz \
    && tar -xzvf rcon.tar.gz \
    && rm rcon.tar.gz \
    && mv rcon-cli-${RCON_VERSION##v}/* ./ \
    && rm -rf rcon-cli-${RCON_VERSION##v} \
    && go build -v ./cmd/gorcon

FROM golang:1.24.5-alpine as supercronic_builder

# SUPERCRONIC: Latest releases available at https://github.com/aptible/supercronic/releases
# renovate: datasource=github-tags depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.34
ENV SUPERCRONIC_VERSION=${SUPERCRONIC_VERSION}

WORKDIR /build

ENV CGO_ENABLED=0
RUN wget -q https://github.com/aptible/supercronic/archive/refs/tags/${SUPERCRONIC_VERSION}.tar.gz -O supercronic.tar.gz \
    && tar -xzvf supercronic.tar.gz \
    && rm supercronic.tar.gz \
    && mv supercronic-${SUPERCRONIC_VERSION##v}/* ./ \
    && rm -rf supercronic-${SUPERCRONIC_VERSION##v} \
    && go build -v .

# False-positive from hadolint
# hadolint ignore=DL3006
FROM ${STEAMCMD_IMAGE}

USER root

# renovate: datasource=github-releases extractVersion=^build-(?<version>.*)$ depName=USA-RedDragon/palworld-server
ARG PALWORLD_VERSION=13585476

# renovate: datasource=repology versioning=deb depName=debian_12/procps
ARG PROCPS_VERSION=2:4.0.2-3
# renovate: datasource=repology versioning=deb depName=debian_12/gettext-base
ARG GETTEXT_BASE_VERSION=0.21-12
# renovate: datasource=repology versioning=deb depName=debian_12/xdg-user-dirs
ARG XDG_USER_DIRS_VERSION=0.18-1

# update and install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps=${PROCPS_VERSION} \
    gettext-base=${GETTEXT_BASE_VERSION} \
    xdg-user-dirs=${XDG_USER_DIRS_VERSION} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# install rcon and supercronic
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=rcon-cli_builder /build/gorcon /usr/bin/rcon-cli
COPY --from=supercronic_builder /build/supercronic /usr/local/bin/supercronic

RUN mkdir -p /palworld /backups \
    && curl -fSsL https://github.com/USA-RedDragon/palworld-server/releases/download/build-${PALWORLD_VERSION}/palworld-server.tar.gz | tar -xz -C /palworld \
    && ln -s /palworld/Pal/Saved /saves

ENV PORT= \
    PLAYERS= \
    MULTITHREADING=false \
    COMMUNITY=false \
    PUBLIC_IP= \
    PUBLIC_PORT= \
    SERVER_PASSWORD= \
    SERVER_NAME= \
    ADMIN_PASSWORD= \
    RCON_ENABLED=true \
    RCON_PORT=25575 \
    QUERY_PORT=27015 \
    TZ=UTC \
    SERVER_DESCRIPTION= \
    BACKUP_ENABLED=true \
    DELETE_OLD_BACKUPS=false \
    OLD_BACKUP_DAYS=30 \
    BACKUP_CRON_EXPRESSION="0 0 * * *" \
    AUTO_REBOOT_ENABLED=false \
    AUTO_REBOOT_CRON_EXPRESSION="0 0 * * *" \
    SHUTDOWN_WARN_SECONDS=300 \
    SHUTDOWN_EVEN_IF_PLAYERS_ONLINE=false

COPY ./scripts /home/steam/server/

RUN chmod +x /home/steam/server/*.sh && \
    mv /home/steam/server/backup.sh /usr/local/bin/backup && \
    mv /home/steam/server/restore.sh /usr/local/bin/restore && \
    mv /home/steam/server/shutdown.sh /usr/local/bin/shutdown

WORKDIR /home/steam/server

RUN chown -R steam:steam /home/steam /palworld /saves /backups

USER steam:steam

HEALTHCHECK --start-period=5m \
    CMD pgrep "PalServer-Linux" > /dev/null || exit 1

EXPOSE ${PORT} ${RCON_PORT}
ENTRYPOINT ["/home/steam/server/init.sh"]
