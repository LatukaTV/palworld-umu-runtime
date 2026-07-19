# syntax=docker/dockerfile:1.7

FROM debian:trixie-slim

LABEL org.opencontainers.image.title="Palworld Windows Mod Runtime"
LABEL org.opencontainers.image.description="Pelican Palworld Windows dedicated server runtime with WineHQ and generic server-mod support"
LABEL org.opencontainers.image.source="https://github.com/LatukaTV/palworld-umu-runtime"
LABEL org.opencontainers.image.licenses="MIT"

ARG TARGETARCH
ARG WINEHQ_VERSION=11.13~trixie-1

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/container
ENV USER=container
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    test "${arch}" = "amd64"; \
    test "$(. /etc/os-release; printf '%s' "${VERSION_CODENAME}")" = "trixie"; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    install -d -m 0755 /etc/apt/keyrings /usr/local/lib/loryvant; \
    install -d -m 0700 /tmp/loryvant-gnupg; \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key -o /etc/apt/keyrings/winehq-archive.key; \
    GNUPGHOME=/tmp/loryvant-gnupg gpg --batch --show-keys --with-colons /etc/apt/keyrings/winehq-archive.key | grep -qi '76F1A20FF987672F'; \
    rm -rf /tmp/loryvant-gnupg; \
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://dl.winehq.org/wine-builds/debian' \
        'Suites: trixie' \
        'Components: main' \
        'Architectures: amd64 i386' \
        'Signed-By: /etc/apt/keyrings/winehq-archive.key' \
        > /etc/apt/sources.list.d/winehq-trixie.sources; \
    apt-get update; \
    apt-get install -y --install-recommends \
        "winehq-devel=${WINEHQ_VERSION}" \
        bash \
        cabextract \
        dbus-x11 \
        jq \
        lib32gcc-s1 \
        lib32stdc++6 \
        passwd \
        procps \
        python3 \
        tar \
        winbind \
        xvfb; \
    test "$(/opt/wine-devel/lib/wine/x86_64-unix/wine --version)" = 'wine-11.13'; \
    test -x /opt/wine-devel/lib/wine/x86_64-unix/wine; \
    test -x /opt/wine-devel/bin/wineboot; \
    test -x /opt/wine-devel/bin/wineserver; \
    test -e /usr/lib32/libstdc++.so.6; \
    test -e /usr/lib32/libgcc_s.so.1; \
    getent group container >/dev/null || groupadd --gid 1000 container; \
    id container >/dev/null 2>&1 || useradd --uid 1000 --gid container --home-dir /home/container --create-home --shell /bin/bash container; \
    install -d -o container -g container -m 0755 /home/container; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    mkdir -p /var/lib/dbus; \
    ln -sf /etc/machine-id /var/lib/dbus/machine-id; \
    ln -sf /opt/wine-devel/lib/wine/x86_64-unix/wine /usr/local/bin/wine64; \
    ln -sf /opt/wine-devel/bin/wineserver /usr/local/bin/wineserver; \
    ln -sf /opt/wine-devel/bin/wineboot /usr/local/lib/loryvant/wineboot-real; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/pelican-entrypoint /usr/local/bin/pelican-entrypoint
COPY scripts/palworld-umu-start /usr/local/bin/palworld-umu-start-core
COPY scripts/palworld-umu-start-wrapper /usr/local/bin/palworld-umu-start
COPY scripts/wineboot-wrapper /usr/local/bin/wineboot-wrapper
COPY scripts/image-preflight.sh /usr/local/bin/palworld-umu-image-preflight
COPY scripts/smoke-test.sh /usr/local/bin/palworld-umu-smoke-test

RUN set -eux; \
    sed -i 's/VERSION = "0.2.10"/VERSION = "0.2.15"/' /usr/local/bin/palworld-umu-start-core; \
    chmod 0755 \
        /usr/local/bin/pelican-entrypoint \
        /usr/local/bin/palworld-umu-start \
        /usr/local/bin/palworld-umu-start-core \
        /usr/local/bin/wineboot-wrapper \
        /usr/local/bin/palworld-umu-image-preflight \
        /usr/local/bin/palworld-umu-smoke-test; \
    ln -sf /usr/local/bin/wineboot-wrapper /usr/local/bin/wineboot; \
    python3 -m py_compile \
        /usr/local/bin/pelican-entrypoint \
        /usr/local/bin/palworld-umu-start \
        /usr/local/bin/palworld-umu-start-core; \
    rm -rf /usr/local/bin/__pycache__; \
    test "$(/usr/local/bin/palworld-umu-start --version)" = "palworld-umu-start 0.2.15"

USER container
WORKDIR /home/container

ENTRYPOINT ["/usr/local/bin/pelican-entrypoint"]
