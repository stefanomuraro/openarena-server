# Build stage
FROM debian:trixie-slim AS builder

ARG TARGETARCH

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
    && git clone https://github.com/OpenArena/engine.git \
    && make -j$(nproc) -C engine \
    && mkdir -p /opt/openarena \
    && cp -r engine/build/release-linux-${ARCH_DIR}/* /opt/openarena \
    && rm -rf engine

RUN wget -O openarena.zip --progress=dot:giga "https://sourceforge.net/projects/oarena/files/openarena-0.8.8.zip/download" \
    && unzip openarena.zip \
    && mkdir -p /opt/openarena/baseoa \
    && cp -r openarena-0.8.8/baseoa/* /opt/openarena/baseoa \
    && rm -rf openarena.zip openarena-0.8.8

# Runtime stage
FROM debian:trixie-slim AS runtime

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-traditional \
    gosu \
    && rm -rf /var/lib/apt/lists/*

ENV UID=1000 \
    GID=1000 \
    SKIP_CHOWN_DATA=false

RUN useradd -r -d /home/openarena -s /bin/bash openarena \
    && mkdir -p /home/openarena

COPY --from=builder /opt/openarena /opt/openarena

RUN case "$TARGETARCH" in \
      amd64) BIN_ARCH="x86_64" ;; \
      arm64) BIN_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: $TARGETARCH (expected amd64 or arm64)" >&2; exit 1 ;; \
    esac \
    && mv /opt/openarena/oa_ded.${BIN_ARCH} /opt/openarena/oa_ded.arm \
    && chmod +x /opt/openarena/oa_ded.arm

RUN mkdir -p /tmp/defaults
COPY config/ /tmp/defaults

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/data"]

RUN chown -R openarena:openarena /opt/openarena /tmp/defaults /home/openarena

EXPOSE 27950/udp
EXPOSE 27960/udp

HEALTHCHECK --timeout=5s --start-period=10s \
  CMD sh -c 'printf "\377\377\377\377getstatus\n" | nc -u -q 1 127.0.0.1 27960 | grep -a -q statusResponse'

ENTRYPOINT ["entrypoint.sh"]
