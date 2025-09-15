# 🐳 Dockerized SVN Server

A secure and optimized Subversion (SVN) server, containerized with Docker and based on Ubuntu 24.04.

## 🎯 What is this image?

This Docker image provides a complete and secure SVN server ready for production. It encapsulates Apache Subversion 1.14.3 in an optimized Ubuntu 24.04 container with enhanced security configuration.

### 🔧 Image Architecture

The image works according to this architecture:

```
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
- **Enhanced security**: dedicated user, restrictive permissions
- **Flexible configuration**: externalized configuration files
- **Optimized image**: based on Ubuntu 24.04, reduced size
- **Production ready**: integrated security and efficiency scans

## 🏗️ How the image is built

### 1. Ubuntu 24.04 Base
The image uses Ubuntu 24.04 LTS as base, ensuring stability and long-term support.

### 2. Subversion Installation
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends subversion=1.14.3-1build4
```

### 3. Secure User Creation
```dockerfile
addgroup svn --system && \
adduser svn --system --home /home/svn --no-create-home --ingroup svn
```

### 4. Permission Configuration
- Removal of default ubuntu user
- Appropriate permissions assignment to `/home/svn` directory
- Configuration files security hardening

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

### 3. Image Building

```bash
./scripts/builder.sh
```

The script automatically performs:
- ✅ Containerfile validation with hadolint
- ✅ Docker image building
- ✅ Tar format saving
- ✅ Efficiency analysis with dive
- ✅ Security scan with trivy
- ✅ Push to registry (if configured)

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

```bash
docker-compose up -d
```

### Custom Configuration

```bash
docker run -d \
  --name svn-server \
  -p 3690:3690 \
  -v svn-data:/home/svn \
  -v ./custom-config:/etc/subversion \
  ghcr.io/deerhide/svn_server_docker:latest
```

## 📁 Project Structure

```
svn_server_docker/
├── Containerfile              # Docker image definition
├── manifest.yaml              # Build configuration
├── docker-compose.yaml        # Docker Compose orchestration
├── subversion/                # SVN configuration files
│   ├── svnserve.conf         # SVN server configuration
│   └── passwd                # Users file
├── scripts/                   # Utility scripts
│   ├── builder.sh            # Main build script
│   ├── install_tools.sh      # Dependencies installation
│   ├── login_docker.sh       # Docker authentication
│   └── login_skopeo.sh       # Skopeo authentication
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

### Adding Users

1. Modify the `subversion/passwd` file
2. Rebuild the image: `./scripts/builder.sh`

### Customizing Configuration

1. Modify files in `subversion/`
2. Rebuild the image: `./scripts/builder.sh`

## 🔒 Security

- **Non-root user** (`svn`): the image doesn't run as root
- **Restrictive permissions**: configuration files are protected
- **Automatic vulnerability scans**: Trivy integration
- **Ubuntu 24.04 LTS base**: long-term support and security updates

## 📊 Monitoring

### Server Logs

```bash
docker logs svn-server
```

### Detailed Logs

```bash
docker exec svn-server cat /var/log/svn/svnserve.log
```

## 🚀 Production Deployment

### Recommended Environment Variables

```bash
# User UID (optional)
APP_UID=1000

# Ubuntu version (optional)
UBUNTU_VERSION=24.04
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

```
SVN Client → Port 3690 → svnserve → Repositories in /home/svn
```

### Repository Management

- **Location**: All repositories are stored in `/home/svn`
- **Permissions**: Owner `svn:svn` with read/write access
- **Persistence**: Use Docker volumes for data persistence

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
