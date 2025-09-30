#!/usr/bin/env bash

set -euo pipefail
echo "[entrypoint] Boot starting"

# Ensure runtime dirs
echo "[entrypoint] Ensuring runtime directories"
mkdir -p /var/log/svn
chmod 755 /var/log/svn || true
echo "[entrypoint] Runtime directories ready"



# Ensure home dir perms
HOME_DIR=${HOME_DIR:-/home/svn}
echo "[entrypoint] Ensuring home permissions in $HOME_DIR"
if [ -d "$HOME_DIR" ]; then
  chown -R svn:svn "$HOME_DIR" || true
  chmod 755 "$HOME_DIR" || true
fi
echo "[entrypoint] Home permissions ensured"

# Seed global Subversion configs into /etc/subversion if bind mount is empty
echo "[entrypoint] Checking Subversion configuration"
SUBVERSION_CONF_DIR="/etc/subversion"
SUBVERSION_DEFAULTS_DIR="/usr/local/share/subversion-defaults"
mkdir -p "$SUBVERSION_CONF_DIR"

# Copy defaults only if files are missing; do not overwrite existing admin-provided configs
if [ -d "$SUBVERSION_DEFAULTS_DIR" ]; then
  if [ ! -f "$SUBVERSION_CONF_DIR/svnserve.conf" ] && [ -f "$SUBVERSION_DEFAULTS_DIR/svnserve.conf" ]; then
    echo "[entrypoint] Seeding /etc/subversion/svnserve.conf from defaults"
    cp "$SUBVERSION_DEFAULTS_DIR/svnserve.conf" "$SUBVERSION_CONF_DIR/svnserve.conf"
  else
    echo "[entrypoint] Skipping svnserve.conf seeding (exists or no default)"
  fi
  if [ ! -f "$SUBVERSION_CONF_DIR/passwd" ] && [ -f "$SUBVERSION_DEFAULTS_DIR/passwd" ]; then
    echo "[entrypoint] Seeding /etc/subversion/passwd from defaults"
    cp "$SUBVERSION_DEFAULTS_DIR/passwd" "$SUBVERSION_CONF_DIR/passwd"
  else
    echo "[entrypoint] Skipping passwd seeding (exists or no default)"
  fi
else
  echo "[entrypoint] Defaults dir not found: $SUBVERSION_DEFAULTS_DIR"
fi

# Ensure secure ownership and permissions for Subversion configs
if [ -d "$SUBVERSION_CONF_DIR" ]; then
  chown -R svn:svn "$SUBVERSION_CONF_DIR" || true
  [ -f "$SUBVERSION_CONF_DIR/svnserve.conf" ] && chmod o-r "$SUBVERSION_CONF_DIR/svnserve.conf" || true
  [ -f "$SUBVERSION_CONF_DIR/passwd" ] && chmod o-r "$SUBVERSION_CONF_DIR/passwd" || true
fi

# Fallback: generate minimal configs if still missing
if [ ! -f "$SUBVERSION_CONF_DIR/svnserve.conf" ]; then
  echo "[entrypoint] Generating minimal /etc/subversion/svnserve.conf"
  cat > "$SUBVERSION_CONF_DIR/svnserve.conf" <<'EOF'
[general]
anon-access = read
auth-access = write
password-db = /etc/subversion/passwd
EOF
fi

if [ ! -f "$SUBVERSION_CONF_DIR/passwd" ]; then
  echo "[entrypoint] Generating minimal /etc/subversion/passwd"
  cat > "$SUBVERSION_CONF_DIR/passwd" <<'EOF'
[users]
svn = svn
EOF
fi


echo "[entrypoint] Starting svnserve"
# Start svnserve in daemon mode but stay in foreground (required: one of -d|-i|-t|-X)
/usr/bin/svnserve -d --foreground -r "$HOME_DIR" --listen-port 3690 --log-file=/var/log/svn/svnserve.log &
SVNSERVE_PID=$!

# Trap signals and forward to child process
term_handler() {
  echo "[entrypoint] Caught termination signal, forwarding to svnserve"
  kill -TERM "$SVNSERVE_PID" 2>/dev/null
  wait "$SVNSERVE_PID"
  echo "[entrypoint] svnserve terminated"
  exit 0
}
trap term_handler SIGTERM SIGINT
# Wait for svnserve process
wait "$SVNSERVE_PID"

echo "[entrypoint] Boot completed"
