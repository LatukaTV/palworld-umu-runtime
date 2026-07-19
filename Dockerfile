# syntax=docker/dockerfile:1.7

FROM ghcr.io/parkervcp/steamcmd:debian

LABEL org.opencontainers.image.title="Palworld Windows Mod Runtime"
LABEL org.opencontainers.image.description="Pelican Palworld Windows dedicated server runtime with Wine and generic server-mod support"
LABEL org.opencontainers.image.source="https://github.com/LatukaTV/palworld-umu-runtime"
LABEL org.opencontainers.image.licenses="MIT"

USER root

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/container
ENV USER=container
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    test "${arch}" = "amd64"; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        cabextract \
        dbus-x11 \
        jq \
        procps \
        python3 \
        tar \
        wine \
        wine32:i386 \
        wine64 \
        winbind \
        xvfb; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    mkdir -p /var/lib/dbus; \
    ln -sf /etc/machine-id /var/lib/dbus/machine-id; \
    ln -sf /usr/bin/wine-stable /usr/local/bin/wine64; \
    ln -sf /usr/bin/wineboot-stable /usr/local/bin/wineboot; \
    ln -sf /usr/bin/wineserver-stable /usr/local/bin/wineserver; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/pelican-entrypoint /usr/local/bin/pelican-entrypoint
COPY scripts/palworld-umu-start /usr/local/bin/palworld-umu-start
COPY scripts/image-preflight.sh /usr/local/bin/palworld-umu-image-preflight
COPY scripts/smoke-test.sh /usr/local/bin/palworld-umu-smoke-test

RUN set -eux; \
    chmod 0755 \
        /usr/local/bin/pelican-entrypoint \
        /usr/local/bin/palworld-umu-start \
        /usr/local/bin/palworld-umu-image-preflight \
        /usr/local/bin/palworld-umu-smoke-test; \
    python3 -m py_compile \
        /usr/local/bin/pelican-entrypoint \
        /usr/local/bin/palworld-umu-start; \
    rm -rf /usr/local/bin/__pycache__; \
    /usr/local/bin/palworld-umu-start --version

USER container
WORKDIR /home/container

ENTRYPOINT ["/usr/local/bin/pelican-entrypoint"]
