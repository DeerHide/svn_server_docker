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

# Volume detection helpers
is_volume_mount() {
  local path="$1"
  # Check if the directory is a mount point or has different device than parent
  if [ -d "$path" ]; then
    local path_dev=$(stat -c %d "$path" 2>/dev/null || echo "unknown")
    local parent_dev=$(stat -c %d "$(dirname "$path")" 2>/dev/null || echo "unknown")

    # If devices are different, it's likely a mount point
    if [ "$path_dev" != "$parent_dev" ] && [ "$path_dev" != "unknown" ] && [ "$parent_dev" != "unknown" ]; then
      return 0  # True - is volume mount
    fi

    # Alternative: check if it's explicitly a mount point
    if mountpoint -q "$path" 2>/dev/null; then
      return 0  # True - is volume mount
    fi
  fi
  return 1  # False - not a volume mount
}

detect_volume_mounts() {
  log "Detecting volume mount status..."

  if is_volume_mount "$HOME_DIR"; then
    log "[OK] $HOME_DIR is a volume mount (repositories will persist)"
    HOME_IS_VOLUME=true
  else
    log "[WARN] $HOME_DIR is not a volume mount (repositories will be ephemeral)"
    HOME_IS_VOLUME=false
  fi

  if is_volume_mount "$SUBVERSION_CONF_DIR"; then
    log "[OK] $SUBVERSION_CONF_DIR is a volume mount (config will persist)"
    CONFIG_IS_VOLUME=true
  else
    log "[WARN] $SUBVERSION_CONF_DIR is not a volume mount (using image defaults)"
    CONFIG_IS_VOLUME=false
  fi

  # Provide helpful guidance
  if [ "$HOME_IS_VOLUME" = "false" ] || [ "$CONFIG_IS_VOLUME" = "false" ]; then
    log ""
    log "   TIP: For persistent data, mount volumes:"
    log "   docker run -v /host/svn-data:/home/svn -v /host/svn-config:/etc/subversion ..."
    log "   or use docker-compose with volume mappings"
    log ""
  fi
}

# Directory Management Functions
setup_runtime_directories() {
  log "Ensuring runtime directories"
  mkdir -p /var/log/svn
  log "Runtime directories ready"
}

setup_home_directory() {
  log "Verifying home directory: $HOME_DIR"

  # Create directory if it doesn't exist
  if [ ! -d "$HOME_DIR" ]; then
    log "Creating home directory: $HOME_DIR"
    mkdir -p "$HOME_DIR"
  fi

  # Check if directory is writable
  if [ -w "$HOME_DIR" ]; then
    log "Home directory exists and is writable"
  else
    log "Error: Home directory $HOME_DIR is not writable"
    log "Current permissions: $(ls -ld "$HOME_DIR" 2>/dev/null || echo 'unknown')"
    exit 1
  fi

  # Verify we can create files in the directory
  local test_file="$HOME_DIR/.write_test_$$"
  if touch "$test_file" 2>/dev/null; then
    rm -f "$test_file"
    log "Home directory write test passed"
  else
    log "Error: Cannot create files in home directory $HOME_DIR"
    exit 1
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
    if [ "$CONFIG_IS_VOLUME" = "true" ]; then
      log "Config directory is volume-mounted, seeding only missing files"
      seed_config_file "svnserve.conf"
      seed_config_file "passwd"
      seed_config_file "authz"
    else
      log "Config directory is not volume-mounted, using image defaults"
      # When not volume-mounted, the image already has the defaults in place
      # Just verify they exist
      local config_files=("svnserve.conf" "passwd" "authz")
      for config_file in "${config_files[@]}"; do
        if [ -f "$SUBVERSION_CONF_DIR/$config_file" ]; then
          log "Using image default: $config_file"
        else
          log "Warning: Missing config file: $config_file"
        fi
      done
    fi
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



# Service Management Functions
start_svnserve() {
  log "Starting svnserve"
  # Start svnserve in daemon mode but stay in foreground (required: one of -d|-i|-t|-X)
  /usr/bin/svnserve -d --foreground -r "$HOME_DIR" --listen-port 3690 --log-file=/var/log/svn/svnserve.log &
  SVNSERVE_PID=$!

  # Wait a moment and check if process is still running
  sleep 2
  if ! kill -0 "$SVNSERVE_PID" 2>/dev/null; then
    log "Error: svnserve failed to start (PID: $SVNSERVE_PID)"
    exit 1
  fi

  log "svnserve started with PID: $SVNSERVE_PID"
}

wait_for_svnserve_ready() {
  log "Waiting for svnserve to be ready..."
  local max_attempts=30
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    # Check if svnserve is listening on port 3690
    if ss -ltn | awk '{print $4}' | grep -qE ":3690$"; then
      log "svnserve is ready and listening on port 3690"
      return 0
    fi

    # Check if process is still running
    if ! kill -0 "$SVNSERVE_PID" 2>/dev/null; then
      log "Error: svnserve process died unexpectedly"
      exit 1
    fi

    log "Attempt $attempt/$max_attempts: svnserve not ready yet, waiting..."
    sleep 1
    attempt=$((attempt + 1))
  done

  log "Error: svnserve failed to become ready within $max_attempts seconds"
  exit 1
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

  # Detect volume mount status
  detect_volume_mounts

  # Setup directories
  setup_runtime_directories
  setup_home_directory

  # Setup configuration
  seed_subversion_configs
  verify_config_permissions

  # Start service
  start_svnserve
  wait_for_svnserve_ready
  setup_signal_handlers
  wait_for_svnserve

  log "Boot completed"
}

# Execute main function
main
