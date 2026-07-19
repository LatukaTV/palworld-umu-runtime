# syntax=docker/dockerfile:1.7

FROM ghcr.io/parkervcp/steamcmd:debian

LABEL org.opencontainers.image.title="Palworld UMU Runtime"
LABEL org.opencontainers.image.description="Pelican SteamCMD runtime with UMU 1.4.0 and GE-Proton11-1 on Debian 13 userspace"
LABEL org.opencontainers.image.source="https://github.com/LatukaTV/palworld-umu-runtime"
LABEL org.opencontainers.image.licenses="MIT"

USER root

ARG TARGETARCH
ARG UMU_VERSION="1.4.0"
ARG UMU_SHA256="138ce4b8843608a257d4bee88191ca78a989778bcefd8abb3c1d1aaac3ac6fb8"
ARG GE_PROTON_VERSION="GE-Proton11-1"

ENV DEBIAN_FRONTEND=noninteractive
ENV PROTONPATH=/opt/ge-proton-host
ENV XDG_DATA_HOME=/home/container/.local/share
ENV XDG_CACHE_HOME=/home/container/.cache
ENV HOME=/home/container
ENV USER=container
ENV PATH=/opt/umu:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    test "${arch}" = "amd64"

# Keep the inherited Pelican SteamCMD entrypoint while moving its userspace to
# Debian 13. GE-Proton11-1 requires glibc 2.38 or newer in host-runtime mode.
RUN set -eux; \
    . /etc/os-release; \
    test "${ID}" = "debian"; \
    if [ "${VERSION_CODENAME:-}" != "trixie" ]; then \
        for source in $(find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \)); do \
            sed -ri 's/(bookworm|bullseye)/trixie/g' "${source}"; \
        done; \
    fi; \
    apt-get update; \
    apt-get full-upgrade -y; \
    apt-get install -y --no-install-recommends \
        bubblewrap \
        ca-certificates \
        curl \
        file \
        fuse-overlayfs \
        jq \
        libzstd1 \
        procps \
        python3 \
        python3-cbor2 \
        python3-filelock \
        python3-xlib \
        python3-xxhash \
        tar \
        xvfb \
        xz-utils \
        zstd; \
    glibc_version="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"; \
    dpkg --compare-versions "${glibc_version}" ge 2.38; \
    grep -Eq '^VERSION_CODENAME=trixie$' /etc/os-release; \
    rm -rf /var/lib/apt/lists/*

# Install the architecture-independent UMU zipapp and verify the exact
# upstream release digest before extraction. The upstream tar currently stores
# umu-run without executable bits, so the runtime image must set them explicitly.
RUN set -eux; \
    curl --fail --location --retry 5 --retry-delay 2 \
        "https://github.com/Open-Wine-Components/umu-launcher/releases/download/${UMU_VERSION}/umu-launcher-${UMU_VERSION}-zipapp.tar" \
        --output /tmp/umu-launcher.tar; \
    printf '%s  %s\n' "${UMU_SHA256}" /tmp/umu-launcher.tar | sha256sum --check --strict -; \
    tar --extract --file /tmp/umu-launcher.tar --directory /opt; \
    chmod 0755 /opt/umu/umu-run; \
    test -x /opt/umu/umu-run; \
    ln -s /opt/umu/umu-run /usr/local/bin/umu-run; \
    rm /tmp/umu-launcher.tar

# Install the official GE-Proton release. The release-provided SHA-512 file
# is downloaded from the same immutable GitHub release tag and must verify
# successfully before extraction.
RUN set -eux; \
    mkdir -p /tmp/ge-proton /opt/ge-proton; \
    cd /tmp/ge-proton; \
    curl --fail --location --retry 5 --retry-delay 2 \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}/${GE_PROTON_VERSION}.tar.gz" \
        --output "${GE_PROTON_VERSION}.tar.gz"; \
    curl --fail --location --retry 5 --retry-delay 2 \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}/${GE_PROTON_VERSION}.sha512sum" \
        --output "${GE_PROTON_VERSION}.sha512sum"; \
    sha512sum --check --strict "${GE_PROTON_VERSION}.sha512sum"; \
    tar --extract --gzip --file "${GE_PROTON_VERSION}.tar.gz" \
        --directory /opt/ge-proton --strip-components=1; \
    test -x /opt/ge-proton/proton; \
    grep -Fq 'CURRENT_PREFIX_VERSION="GE-Proton11-1"' /opt/ge-proton/proton; \
    rm -rf /tmp/ge-proton

# UMU normally follows GE-Proton's require_tool_appid into pressure-vessel.
# Pelican's default Seccomp and AppArmor policies block that nested sandbox.
# The host manifest keeps GE-Proton intact but removes only that runtime edge.
RUN set -eux; \
    mkdir -p /opt/ge-proton-host; \
    find /opt/ge-proton -mindepth 1 -maxdepth 1 ! -name toolmanifest.vdf \
        -exec ln -s '{}' /opt/ge-proton-host/ ';'; \
    awk '!/require_tool_appid/' \
        /opt/ge-proton/toolmanifest.vdf \
        > /opt/ge-proton-host/toolmanifest.vdf; \
    test -x /opt/ge-proton-host/proton; \
    test -s /opt/ge-proton-host/toolmanifest.vdf; \
    ! grep -q require_tool_appid /opt/ge-proton-host/toolmanifest.vdf; \
    grep -q 'compatmanager_layer_name.*proton' /opt/ge-proton-host/toolmanifest.vdf

RUN set -eux; \
    mkdir -p \
        /home/container/.cache \
        /home/container/.local/share \
        /home/container/.umu/prefixes; \
    chown -R container:container \
        /home/container/.cache \
        /home/container/.local \
        /home/container/.umu

COPY scripts/image-preflight.sh /usr/local/bin/palworld-umu-image-preflight
COPY scripts/smoke-test.sh /usr/local/bin/palworld-umu-smoke-test
RUN chmod 0755 \
        /usr/local/bin/palworld-umu-image-preflight \
        /usr/local/bin/palworld-umu-smoke-test

USER container
WORKDIR /home/container

# Validation runs against the completed candidate container in GitHub Actions.
# Keeping it outside Docker build layers preserves the complete failing output
# and prevents an opaque BuildKit "RUN ... exit code 1" annotation.
