# Contributing to SVN Server Docker

## 🚀 Quick Start

1. **Fork and clone**

   ```bash
   git clone https://github.com/your-username/svn_server_docker.git
   cd svn_server_docker
   ```

2. **Setup development environment**

   ```bash
   ./scripts/install_tools.sh
   export SSH_AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)"
   docker-compose up -d
   ```

## 📝 Contributing

### Submitting Changes

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes and test:

   ```bash
   docker-compose up -d
   svn checkout svn://localhost:3690/hello
   svn checkout svn+ssh://svn@localhost:2222/hello
   ```

3. Commit with conventional format: `git commit -m "feat: your change"`
4. Push and create Pull Request

### Guidelines

- **Code Style**: Follow existing patterns, use spaces for indentation
- **Testing**: Test both SVN protocol (3690) and SSH access (2222)
- **Documentation**: Update README.md for user-facing changes
- **Security**: Review SSH config and permission handling

### Key Areas

- `Containerfile` - Docker image definition
- `scripts/` - Build and utility scripts
- `src/` - Configuration templates
- Documentation - README.md, TODO.md

### Commit Format

- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation
- `refactor:` code changes
- `chore:` maintenance

## 🤝 Code of Conduct

Be respectful, inclusive, and focus on constructive feedback.

Thank you for contributing! 🎉
