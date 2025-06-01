#latest alpine image from Alpine Team
FROM alpine:latest 
LABEL maintainer="https://github.com/slautomaton/factorio"

# downloads the factorio headless into /tmp, 
# unpacks it into /opt/factorio 
# makes /saves and /mods folders

# Instantiates args which are variables that can passed from docker CLI into here.

ARG USER=factorio
ARG GROUP=factorio
ARG PUID=845
ARG PGID=845
ARG CURL_RETRIES=8
ARG PRESET
ARG VERSION
ARG SHA256

ENV PORT=34197 \
    RCON_PORT=27015 \
    SAVES=/factorio/saves \
    PRESET="$PRESET" \
    CONFIG=/factorio/config \
    MODS=/factorio/mods \
    SCENARIOS=/factorio/scenarios \
    SCRIPTOUTPUT=/factorio/script-output \
    PUID="$PUID" \
    PGID="$PGID" \
    DLC_SPACE_AGE="true"

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# RUN apk add --update --no-cache tini pwgen gcompat curl && \
#     apk add --update --no-cache --virtual .build-deps && \
#     curl -sSL https://www.factorio.com/get-download/$VERSION/headless/linux64 \
#         -o /tmp/factorio_headless_x64_$VERSION.tar.xz && \
#     tar xf /tmp/factorio_headless_x64_$VERSION.tar.xz --directory /opt && \
#     rm /tmp/factorio_headless_x64_$VERSION.tar.xz && \
#     ln -s /factorio/saves /opt/factorio/saves && \
#     ln -s /factorio/mods /opt/factorio/mods && \
#     apk del .build-deps

# installs base dependencies to run Glib programs, sets non-root user
RUN apk add --update --no-cache tini pwgen gcompat curl && \
    apk add --update --no-cache --virtual .build-deps && \
    apk del .build-deps && \
    addgroup --system --gid "$PGID" "$GROUP" && \
    adduser --system --uid "$PUID" --gid "$PGID" --no-create-home --disabled-password --shell /bin/sh "$USER"

LABEL factorio.version=${VERSION}

ENV VERSION=${VERSION} \
    SHA256=${SHA256}

RUN set -ox pipefail \
    && if [[ "${VERSION}" == "" ]]; then \
        echo "build-arg VERSION is required" \
        && exit 1; \
    fi \
    && if [[ "${SHA256}" == "" ]]; then \
        echo "build-arg SHA256 is required" \
        && exit 1; \
    fi \
    && archive="/tmp/factorio_headless_x64_$VERSION.tar.xz" \
    && mkdir -p /opt /factorio \
    && curl -sSL "https://www.factorio.com/get-download/$VERSION/headless/linux64" -o "$archive" --retry $CURL_RETRIES \
    && echo "$SHA256  $archive" | sha256sum -c \
    || (sha256sum "$archive" && file "$archive" && exit 1) \
    && tar xf "$archive" --directory /opt \
    && chmod ugo=rwx /opt/factorio \
    && rm "$archive" \
    && ln -s "$SCENARIOS" /opt/factorio/scenarios \
    && ln -s "$SAVES" /opt/factorio/saves \
    && mkdir -p /opt/factorio/config/ \
    && chown -R "$USER":"$GROUP" /opt/factorio /factorio

VOLUME /etc/home/slau/factorio:/factorio

EXPOSE $PORT/udp $RCON_PORT/tcp

COPY ./sh/*.sh /
COPY ./.files/server-settings.json /opt/factorio/data
COPY ./.files/server-whitelist.json /opt/factorio/data

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]