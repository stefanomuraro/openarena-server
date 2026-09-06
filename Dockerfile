# syntax=docker/dockerfile:1

# Build stage
FROM debian:trixie-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
ARG DL_TIMEOUT=120

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    make \
    git \
    build-essential \
    libsdl1.2-dev \
    libxmp-dev \
    libsdl2-dev \
    libgl1-mesa-dev \
    libvorbis-dev \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) ARCH_DIR="x86_64" ;; \
      arm64) ARCH_DIR="aarch64" ;; \
      *) echo "Unsupported architecture: $TARGETARCH (expected amd64 or arm64)" >&2; exit 1 ;; \
    esac \
    && git init engine \
    && git -C engine remote add origin https://github.com/OpenArena/engine.git \
    && git -C engine fetch --depth 1 origin 95c63426c896b2f6277ee940f053a649dd97364a \
    && git -C engine checkout --detach FETCH_HEAD \
    && make -j"$(nproc)" -C engine \
    && mkdir -p /opt/openarena \
    && cp -r engine/build/release-linux-${ARCH_DIR}/* /opt/openarena \
    && mv /opt/openarena/oa_ded.${ARCH_DIR} /opt/openarena/oa_ded.arm \
    && rm -rf engine

RUN ok=0; \
    urls="https://archive.org/download/openarena-0.8.8/openarena-0.8.8.zip \
          https://sourceforge.net/projects/oarena/files/openarena-0.8.8.zip/download \
          http://download.tuxfamily.org/openarena/rel/088/openarena-0.8.8.zip"; \
    for url in $urls; do \
      echo "==> Trying $url"; \
      timeout "$DL_TIMEOUT" wget --tries=3 --timeout=30 --waitretry=2 --progress=dot:giga -O openarena.zip "$url" \
        && echo "37ab41990b37459822ce8c2fe590607616e1f6d1  openarena.zip" | sha1sum -c - \
        && { ok=1; break; }; \
    done; \
    if [ "$ok" != 1 ]; then \
      echo "==> Initial mirror attempts failed; retrying without an overall time limit"; \
      for url in $urls; do \
        echo "==> Trying $url (no overall limit)"; \
        wget --tries=3 --timeout=30 --waitretry=2 --progress=dot:giga -O openarena.zip "$url" \
          && echo "37ab41990b37459822ce8c2fe590607616e1f6d1  openarena.zip" | sha1sum -c - \
          && { ok=1; break; }; \
      done; \
      [ "$ok" = 1 ]; \
    fi \
    && unzip openarena.zip \
    && mkdir -p /opt/openarena/baseoa \
    && cp -r openarena-0.8.8/baseoa/* /opt/openarena/baseoa \
    && rm -rf openarena.zip openarena-0.8.8

# Runtime stage
FROM debian:trixie-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-traditional \
    gosu \
    && rm -rf /var/lib/apt/lists/*

ENV UID=1000 \
    GID=1000 \
    SKIP_CHOWN_DATA=false \
    PUBLIC=false

RUN useradd -r -d /home/openarena -s /bin/bash openarena \
    && mkdir -p /home/openarena \
    && chown openarena:openarena /home/openarena

COPY --from=builder --chown=openarena:openarena /opt/openarena /opt/openarena

COPY --chown=openarena:openarena config/ /tmp/defaults

COPY --chmod=+x entrypoint.sh /usr/local/bin/entrypoint.sh

VOLUME ["/data"]

EXPOSE 27950/udp
EXPOSE 27960/udp

HEALTHCHECK --timeout=5s --start-period=10s \
  CMD ["sh", "-c", "printf \"\\377\\377\\377\\377getstatus\\n\" | nc -u -q 1 127.0.0.1 27960 | grep -a -q statusResponse"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
