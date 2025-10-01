#!/usr/bin/env bash

set -euo pipefail

# Global variables
HOME_DIR=${HOME_DIR:-/home/svn}
SUBVERSION_CONF_DIR="/etc/subversion"
SUBVERSION_DEFAULTS_DIR="/usr/local/share/subversion-defaults"
SVNSERVE_PID=""

# Logging helper
log() {
  echo "[entrypoint] $*"
}

# User context helper
log_user_context() {
  log "Running as user: $(whoami) (UID: $(id -u), GID: $(id -g))"
  log "Home directory: $HOME_DIR"
}

# Directory Management Functions
setup_runtime_directories() {
  log "Ensuring runtime directories"
  mkdir -p /var/log/svn
  log "Runtime directories ready"
}

setup_home_directory() {
  log "Verifying home directory: $HOME_DIR"
  if [ -d "$HOME_DIR" ]; then
    log "Home directory exists and accessible"
  else
    log "Warning: Home directory $HOME_DIR does not exist"
  fi
}

# Configuration Management Functions
seed_config_file() {
  local config_name="$1"
  local source_file="$SUBVERSION_DEFAULTS_DIR/$config_name"
  local target_file="$SUBVERSION_CONF_DIR/$config_name"

  if [ ! -f "$target_file" ] && [ -f "$source_file" ]; then
    log "Seeding /etc/subversion/$config_name from defaults"
    cp "$source_file" "$target_file"
  else
    log "Skipping $config_name seeding (exists or no default)"
  fi
}

seed_subversion_configs() {
  log "Checking Subversion configuration"
  mkdir -p "$SUBVERSION_CONF_DIR"

  if [ -d "$SUBVERSION_DEFAULTS_DIR" ]; then
    seed_config_file "svnserve.conf"
    seed_config_file "passwd"
    seed_config_file "authz"
  else
    log "Defaults dir not found: $SUBVERSION_DEFAULTS_DIR"
  fi
}

verify_config_permissions() {
  if [ -d "$SUBVERSION_CONF_DIR" ]; then
    log "Configuration directory accessible: $SUBVERSION_CONF_DIR"
    # Just verify we can read the config files - permissions are set at build time or by volume mounts
    local config_files=("svnserve.conf" "passwd" "authz")
    for config_file in "${config_files[@]}"; do
      if [ -f "$SUBVERSION_CONF_DIR/$config_file" ]; then
        log "Config file accessible: $config_file"
      else
        log "Config file missing: $config_file"
      fi
    done
  else
    log "Warning: Configuration directory not accessible: $SUBVERSION_CONF_DIR"
  fi
}


generate_minimal_passwd() {
  if [ ! -f "$SUBVERSION_CONF_DIR/passwd" ]; then
    log "Generating minimal /etc/subversion/passwd"
    cat > "$SUBVERSION_CONF_DIR/passwd" <<'EOF'
[users]
svn = svn
EOF
  fi
}

generate_minimal_authz() {
  if [ ! -f "$SUBVERSION_CONF_DIR/authz" ]; then
    log "Generating minimal /etc/subversion/authz"
    cat > "$SUBVERSION_CONF_DIR/authz" <<'EOF'
[groups]

[/]
* = rw
EOF
  fi
}

ensure_minimal_configs() {
  generate_minimal_passwd
  generate_minimal_authz
}

# Service Management Functions
start_svnserve() {
  log "Starting svnserve"
  # Start svnserve in daemon mode but stay in foreground (required: one of -d|-i|-t|-X)
  /usr/bin/svnserve -d --foreground -r "$HOME_DIR" --listen-port 3690 --log-file=/var/log/svn/svnserve.log &
  SVNSERVE_PID=$!
}

setup_signal_handlers() {
  # Trap signals and forward to child process
  term_handler() {
    log "Caught termination signal, forwarding to svnserve"
    kill -TERM "$SVNSERVE_PID" 2>/dev/null
    wait "$SVNSERVE_PID"
    log "svnserve terminated"
    exit 0
  }
  trap term_handler SIGTERM SIGINT
}

wait_for_svnserve() {
  # Wait for svnserve process
  wait "$SVNSERVE_PID"
}

# Main execution flow
main() {
  log "Boot starting"
  log_user_context

  # Setup directories
  setup_runtime_directories
  setup_home_directory

  # Setup configuration
  seed_subversion_configs
  verify_config_permissions
  ensure_minimal_configs

  # Start service
  start_svnserve
  setup_signal_handlers
  wait_for_svnserve

  log "Boot completed"
}

# Execute main function
main
