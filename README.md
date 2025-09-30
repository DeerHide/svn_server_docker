# 🐳 Dockerized SVN Server

A secure and optimized Subversion (SVN) server, containerized with Docker and based on Ubuntu 24.04.

## 🎯 What is this image?

This Docker image provides a complete and secure SVN server ready for production. It encapsulates Apache Subversion 1.14.3 in an optimized Ubuntu 24.04 container with enhanced security configuration.

### 🔧 Image Architecture

The image works according to this architecture:

```text
┌───────────────────────────────────────┐
│           Docker Container            │
│  ┌──────────────────────────────────┐ │
│  │        Ubuntu 24.04 LTS          │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │     Apache Subversion       │ │ │
│  │  │        1.14.3               │ │ │
│  │  └─────────────────────────────┘ │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │     'svn' User              │ │ │
│  │  │    (non-root, secure)       │ │ │
│  │  └─────────────────────────────┘ │ │
│  └──────────────────────────────────┘ │
│  Port 3690 (SVN Protocol)             │
└───────────────────────────────────────┘
```

## 🚀 Key Features

- **Complete SVN server** with Apache Subversion 1.14.3
- **SVN protocol support**: Native SVN protocol (port 3690) for repository access
- **Multi-architecture support**: AMD64 and ARM64 platforms
- **Enhanced security**: dedicated user, restrictive permissions, secure configuration
- **Flexible configuration**: externalized configuration files with automatic seeding
- **Health monitoring**: built-in healthcheck for SVN service
- **Optimized image**: based on Ubuntu 24.04, reduced size
- **Production ready**: integrated security and efficiency scans

## 🏗️ How the image is built

### 1. Ubuntu 24.04 Base

The image uses Ubuntu 24.04 LTS as base, ensuring stability and long-term support.

### 2. Multi-Architecture Support

The image is built for multiple architectures:

- **linux/amd64**: Intel/AMD 64-bit processors
- **linux/arm64**: ARM 64-bit processors (Apple Silicon, ARM servers)

### 3. Subversion Installation

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends subversion=1.14.3-1build4
```

### 4. Secure User and Group Management

```dockerfile
# Remove default ubuntu user and reuse its UID/GID
deluser --remove-home ubuntu && \
addgroup --system --gid ${APP_GID} svn && \
adduser --system --uid ${APP_UID} --home ${HOME_DIR} --no-create-home --ingroup svn svn
```

### 5. Permission Configuration

- **User Management**: Reuses UID/GID 1000 from removed ubuntu user
- **Directory Permissions**: `/home/svn` with 755 permissions (svn:svn ownership)
- **Security Hardening**: Configuration files with restricted access
- **Bash Configuration**: Custom shell setup for svn user

## 📋 Prerequisites

### Docker Installation

[See Docker documentation](https://docs.docker.com/get-docker/)

### Development Tools Installation

```bash
./scripts/install_tools.sh
```

## 🛠️ Building the Image

### 1. Manifest Configuration

Modify the `manifest.yaml` file according to your needs:

```yaml
name: svn_server_docker
tags:
  - latest
registry: ghcr.io/deerhide/svn_server_docker
build:
  format: oci
  args:
    - APP_UID=1000
    - UBUNTU_VERSION=24.04
```

### 2. Registry Authentication

```bash
# Connect to GitHub Container Registry
# Use the provided script for docker:
./scripts/login_docker.sh

# Or for skopeo:
./scripts/login_skopeo.sh
```

### 3. Multi-Architecture Image Building

```bash
./scripts/builder.sh
```

The script performs:

- ✅ Multi-architecture image builds using Buildah (AMD64 + ARM64)
- ✅ Saves per-arch images as tar archives for analysis
- ✅ Filesystem efficiency scans with Dive for each architecture
- ✅ Pushes per-arch images to the registry with Skopeo
- ✅ Creates and pushes a multi-arch manifest (Docker manifest)

Notes:

- Hadolint validation is available but disabled by default in the script
  (uncomment in `scripts/builder.sh` to enable).
- Trivy vulnerability scanning is installed via `./scripts/install_tools.sh` but
  disabled by default in the build script (uncomment to enable).

## 🐳 Usage

### Simple Startup

```bash
docker run -d \
  --name svn-server \
  -p 3690:3690 \
  -v svn-data:/home/svn \
  ghcr.io/deerhide/svn_server_docker:latest
```

### With Docker Compose

The project includes a `docker-compose.yaml` file for easy testing and development:

```bash
# Start the SVN server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

**Environment Variables:**

- `HOME_DIR`: Override the home directory path (default: `/home/svn`)

### Custom Configuration

```bash
docker run -d \
  --name svn-server \
  -p 3690:3690 \
  -v svn-data:/home/svn \
  -v ./custom-config:/etc/subversion \
  ghcr.io/deerhide/svn_server_docker:latest
```

### SVN Protocol Access

Access repositories using the native SVN protocol:

```bash
# Clone a repository via SVN protocol
svn checkout svn://localhost:3690/hello

# Or using full path
svn checkout svn://localhost:3690/home/svn/hello
```

**SVN Protocol Configuration:**

- Port: 3690
- Authentication: SVN built-in authentication (username/password)
- Protocol: Native SVN protocol for optimal performance

## 📁 Project Structure

```text
svn_server_docker/
├── Containerfile              # Docker image definition
├── manifest.yaml              # Build configuration
├── docker-compose.yaml        # Docker Compose orchestration
├── src/                       # Source configuration files
│   └── subversion/           # SVN configuration templates
│       ├── svnserve.conf     # SVN server configuration
│       └── passwd            # Users file template
├── scripts/                   # Utility scripts
│   ├── builder.sh            # Main build script
│   ├── entrypoint.sh         # Container entrypoint script
│   ├── healthcheck.sh        # Health monitoring script
│   ├── install_tools.sh      # Dependencies installation
│   ├── launch.sh             # Development launch helper
│   ├── lib_utils.sh          # Utility functions
│   ├── login_docker.sh       # Docker authentication
│   └── login_skopeo.sh       # Skopeo authentication
├── svn_config/               # Runtime SVN configuration (bind mount)
│   ├── svnserve.conf         # Active SVN server configuration
│   └── passwd                # Active users file
├── svn_data/                 # SVN repositories (bind mount)
│   ├── hello/                # Sample repository
│   └── world/                # Sample repository
├── TODO.md                   # Development tasks and hardening notes
└── README.md                 # This file
```

## ⚙️ Configuration

### svnserve.conf File

```ini
[general]
anon-access = none          # No anonymous access
auth-access = write         # Write access for authenticated users
password-db = /etc/subversion/passwd  # Password file
realm = SVN Server          # Authentication realm name
```

### passwd File

```ini
[users]
# name = password
admin = password123
user1 = another_password
```

## 🔧 Development

### Development and Testing

**Docker Compose Configuration:**

- **Ports**: 3690 (SVN protocol)
- **Volumes**:
  - `./svn_data:/home/svn` (SVN repositories)
  - `./svn_config:/etc/subversion` (SVN configuration)
- **Build**: Uses local `Containerfile` for development
- **Health Check**: Built-in health monitoring for SVN service

**Note**: The `./svn_data` directory can be prepared automatically with correct permissions (1000:1000) by running `./scripts/launch.sh`.

**Development Commands:**

```bash
# Start development environment
docker-compose up -d

# Check container status and health
docker-compose ps

# View real-time logs
docker-compose logs -f svn

# Access container shell
docker-compose exec svn bash

# Test SVN access via protocol
svn checkout svn://localhost:3690/hello

# Stop and clean up
docker-compose down
```

### Adding Users

**For SVN Protocol Access:**

1. Modify the `svn_config/passwd` file (runtime configuration)
2. Restart the container: `docker-compose restart`

### Customizing Configuration

**Runtime Configuration (Recommended):**

1. Modify files in `svn_config/` directory
2. Restart the container: `docker-compose restart`

**Build-time Configuration:**

1. Modify files in `src/subversion/`
2. Rebuild the image: `./scripts/builder.sh`

## 🔒 Security

- **Non-root user** (`svn`): the image doesn't run as root
- **Restrictive permissions**: configuration files are protected
- **Automatic vulnerability scans**: Trivy integration
- **Ubuntu 24.04 LTS base**: long-term support and security updates

## 📊 Monitoring

### Health Checks

The container includes built-in health monitoring for the SVN service:

```bash
# Check container health status
docker ps
# Look for "healthy" status in the STATUS column

# Manual health check
docker exec svn-server /usr/local/bin/healthcheck.sh

# Health check details
docker inspect svn-server | jq '.[0].State.Health'
```

**Health Check Configuration:**

- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Retries**: 3 attempts
- **Checks**: SVN service (port 3690)

### Server Logs

```bash
# Container logs
docker logs svn-server

# Follow logs in real-time
docker logs -f svn-server

# Docker Compose logs
docker-compose logs -f svn
```

### Detailed Logs

```bash
# SVN server logs
docker exec svn-server cat /var/log/svn/svnserve.log

# System logs
docker exec svn-server journalctl -f
```

## 🚀 Production Deployment

### Build Arguments

Build arguments are defined in `manifest.yaml` and passed by the builder script:

```bash
# User UID (default: 1000)
APP_UID=1000

# Group GID (default: 1000)
APP_GID=1000

# Ubuntu version (default: 24.04)
UBUNTU_VERSION=24.04
```

### Recommended Environment Variables

```bash
# SVN Repository Configuration
SVN_REPO_NAME=my_repo
SVN_REPO_PATH=/home/svn/${SVN_REPO_NAME}
SVN_REPO_URL=file://${SVN_REPO_PATH}
```

### Recommended Resources

- **CPU**: 1 core minimum
- **RAM**: 512 MB minimum
- **Storage**: 10 GB minimum (depending on repository size)

## 🔍 How it works technically

### Startup Process

1. **Initialization**: Container starts with `svn` user
2. **Configuration**: Loading configuration files from `/etc/subversion/`
3. **Service startup**: Launching `svnserve` in daemon mode
4. **Listening**: Server listens on port 3690 for SVN connections

### Data Flow

```text
SVN Client → Port 3690 → svnserve → Repositories in /home/svn
```

### Repository Management

- **Location**: All repositories are stored in `/home/svn`
- **Permissions**: Owner `svn:svn` (UID:GID 1000:1000) with 755 permissions
- **Persistence**: Use Docker volumes for data persistence
- **User Management**: Reuses UID/GID from removed ubuntu user for consistency

### Permission Handling

- **Volume Mounts**: Automatic permission correction for mounted volumes
- **User Consistency**: UID/GID 1000:1000 matches common host user permissions
- **Security**: Non-root user with restricted access to configuration files

### Volume Mount Requirements

When mounting volumes to `/home/svn`, ensure the host directory has correct permissions:

```bash
# Create directory with correct ownership
sudo mkdir -p /path/to/svn-data
sudo chown -R 1000:1000 /path/to/svn-data
sudo chmod -R 755 /path/to/svn-data

# Or using Ansible
- name: Create SVN data directory
  ansible.builtin.file:
    name: path/to/data
    state: directory
    mode: "755"
    owner: "1000"
    group: "1000"
    recurse: true
```

**Important**: The container runs as UID:GID 1000:1000, so mounted volumes must have matching ownership to avoid permission issues.

## 📝 License

This project is licensed under the MIT License. See the `LICENSE` file for more details.

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the project
2. Create a branch for your feature
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📞 Support

For any questions or issues:

- Open an issue on GitHub
- Check Subversion documentation
- Check container logs

---

**Note**: This project is an optimized Docker container template for Subversion servers. It follows security and efficiency best practices.
