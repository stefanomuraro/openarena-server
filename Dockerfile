# Build stage
FROM debian:trixie-slim AS builder

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

RUN git clone https://github.com/OpenArena/engine.git \
    && sed -i 's/arm/aarch64/g' engine/code/qcommon/q_platform.h \
    && make -j$(nproc) -C engine \
    && mkdir -p /opt/openarena \
    && cp -r engine/build/release-linux-aarch64/* /opt/openarena \
    && rm -rf engine

RUN wget -O openarena.zip --progress=dot:giga "https://sourceforge.net/projects/oarena/files/openarena-0.8.8.zip/download" \
    && unzip openarena.zip \
    && mkdir -p /opt/openarena/baseoa \
    && cp -r openarena-0.8.8/baseoa/* /opt/openarena/baseoa \
    && rm -rf openarena.zip openarena-0.8.8

# Runtime stage
FROM debian:trixie-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/openarena /opt/openarena

RUN mv /opt/openarena/oa_ded.aarch64 /opt/openarena/oa_ded.arm \
    && chmod +x /opt/openarena/oa_ded.arm

RUN mkdir -p /tmp/defaults
COPY config/ /tmp/defaults

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/data"]

EXPOSE 27950/udp
EXPOSE 27960/udp

HEALTHCHECK --timeout=5s --start-period=10s \
  CMD sh -c 'printf "\377\377\377\377getstatus\n" | nc -u -q 1 127.0.0.1 27960 | grep -a -q statusResponse'

ENTRYPOINT ["entrypoint.sh"]
