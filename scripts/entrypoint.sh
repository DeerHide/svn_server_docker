#!/usr/bin/env bash

set -euo pipefail
echo "[entrypoint] Boot starting"

# Ensure runtime dirs
echo "[entrypoint] Ensuring runtime directories"
mkdir -p /run/sshd /var/log/svn
chmod 755 /run/sshd /var/log/svn || true
echo "[entrypoint] Runtime directories ready"

# Ensure SSH host keys exist (per-container) and have secure permissions
echo "[entrypoint] Verifying SSH host keys"
HOST_KEY_DIR="/etc/ssh"
if ! ls ${HOST_KEY_DIR}/ssh_host_*_key >/dev/null 2>&1; then
  echo "[entrypoint] SSH host keys missing; generating"
  ssh-keygen -A
else
  echo "[entrypoint] SSH host keys already present"
fi
# Enforce secure ownership and permissions
chown root:root ${HOST_KEY_DIR}/ssh_host_*_key* 2>/dev/null || true
chmod 600 ${HOST_KEY_DIR}/ssh_host_*_key 2>/dev/null || true
chmod 644 ${HOST_KEY_DIR}/ssh_host_*_key.pub 2>/dev/null || true
echo "[entrypoint] SSH host key permissions set"


# Ensure home and ssh dir perms
HOME_DIR=${HOME_DIR:-/home/svn}
echo "[entrypoint] Ensuring home and SSH permissions in $HOME_DIR"
if [ -d "$HOME_DIR" ]; then
  chown -R svn:svn "$HOME_DIR" || true
  chmod 755 "$HOME_DIR" || true
  mkdir -p "$HOME_DIR/.ssh"
  chown -R svn:svn "$HOME_DIR/.ssh"
  chmod 700 "$HOME_DIR/.ssh"
  if [ -f "$HOME_DIR/.ssh/authorized_keys" ]; then
    chown svn:svn "$HOME_DIR/.ssh/authorized_keys"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
  fi
fi
echo "[entrypoint] Home and SSH permissions ensured"

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

# Populate authorized_keys from environment variables if provided
sanitize_keys() {
  # Remove CRs, trim whitespace
  sed -e 's/\r$//' -e 's/^\s\+//' -e 's/\s\+$//' | sed '/^$/d'
}

AUTH_KEYS_FILE="$HOME_DIR/.ssh/authorized_keys"
# Always overwrite with env-provided keys only
if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
  # Support newline-separated and literal \n-separated keys without corrupting characters
  printf "%s" "$SSH_AUTHORIZED_KEYS" \
    | sed 's/\\\n/\n/g' \
    | sanitize_keys > "$AUTH_KEYS_FILE"
else
  # Create empty file if no keys provided so sshd can start; warn for visibility
  : > "$AUTH_KEYS_FILE"
  echo "[entrypoint] Warning: SSH_AUTHORIZED_KEYS is empty; no SSH logins will be allowed." >&2
fi
chmod 600 "$AUTH_KEYS_FILE" && chown svn:svn "$AUTH_KEYS_FILE"

# Start sshd (key-only per config)
echo "[entrypoint] Starting sshd"
/usr/sbin/sshd -D -e &

# Start svnserve in daemon mode but stay in foreground (required: one of -d|-i|-t|-X)
echo "[entrypoint] Starting svnserve"
exec /usr/bin/svnserve -d --foreground -r "$HOME_DIR" --listen-port 3690 --log-file=/var/log/svn/svnserve.log

echo "[entrypoint] Boot completed"
