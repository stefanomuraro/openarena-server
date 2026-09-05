# OpenArena Server

[![Docker Image](https://img.shields.io/docker/v/stefanomuraro/openarena-server?label=dockerhub)](https://hub.docker.com/r/stefanomuraro/openarena-server)
[![Docker Image Size](https://img.shields.io/docker/image-size/stefanomuraro/openarena-server/latest)](https://hub.docker.com/r/stefanomuraro/openarena-server)
[![Docker Pulls](https://img.shields.io/docker/pulls/stefanomuraro/openarena-server)](https://hub.docker.com/r/stefanomuraro/openarena-server)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)

Dedicated server for [OpenArena](https://openarena.ws/) v0.8.8, built as a multi-arch Docker image supporting amd64 and arm64.

## Quick Start

```bash
docker pull stefanomuraro/openarena-server:latest
docker run -d -p 27950:27950/udp -p 27960:27960/udp -v ./data:/data stefanomuraro/openarena-server
```

## Compose File

```yaml
services:
  openarena-server:
    image: stefanomuraro/openarena-server:latest
    restart: unless-stopped
    ports:
      - "27950:27950/udp"
      - "27960:27960/udp"
    volumes:
      - ./data:/data
```

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `UID` | `1000` | User ID the server process runs as. Matched to the host user so bind-mounted `/data` is writable. |
| `GID` | `1000` | Group ID the server process runs as. |
| `SKIP_CHOWN_DATA` | `false` | Set to `true` to skip changing ownership of `/data` on startup. |
| `PUBLIC` | `false` | When `true`, the server runs with `dedicated 2` and is broadcast to the master server (public). When `false`, it runs with `dedicated 1` (LAN/friends only, connect via your direct address). Set `PUBLIC=true` to expose the server publicly. |

The container starts as root to remap the `openarena` user to the requested `UID`/`GID` and fix bind-mount ownership, then runs the game server as the non-root `openarena` user.

## Persistent Data

Mount a volume at `/data` to persist config and maps.

```
/data/
├── config/
│   ├── game.cfg          # Game settings
│   ├── motd.cfg          # Message of the day
│   └── server.cfg        # Main server configuration
├── maps/                 # Add your custom .pk3 maps here
└── server.log            # Server log file
```

## Supported Platforms
- `linux/amd64`
- `linux/arm64`

## Building Locally

Requires Docker with the buildx plugin, so that `TARGETARCH` is set and the architecture mapping in the Dockerfile resolves correctly.

```bash
docker compose up -d
```

## License

[GPLv3](LICENSE)
